import AVFoundation
import Photos
import SwiftUI

final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "camera.session")
    private var device: AVCaptureDevice?
    private var zoomScale: CGFloat = 1
    private var images: [Data] = []
    private var captureError: String?
    private var shouldRun = false
    private var runningObservation: NSKeyValueObservation?
    private var interruptionObservation: NSKeyValueObservation?
    private var runtimeErrorObserver: NSObjectProtocol?

    enum Unavailability {
        case permissionDenied
        case noCamera
        case failure(String)
    }

    @Published private(set) var unavailability: Unavailability?
    @Published private(set) var sessionRunning = false
    @Published private(set) var interrupted = false
    @Published private(set) var switchingCamera = false
    @Published var busy = false
    @Published var message: String?
    @Published var maxCount = 0
    @Published var minBias: Float = -2
    @Published var maxBias: Float = 2
    @Published var count = 3
    @Published var spacing: Float = 1
    @Published var center: Float = 0
    @Published var showGrid = false
    @Published var lastCapture: String?
    @Published var recentPhotos: [UIImage] = []
    @Published private(set) var zoom: CGFloat = 1
    @Published private(set) var maxZoom: CGFloat = 1
    @Published private(set) var minZoom: CGFloat = 1
    @Published private(set) var zoomPresets: [CGFloat] = [1]

    var ready: Bool { sessionRunning && !interrupted && !switchingCamera }

    override init() {
        super.init()
        runningObservation = session.observe(\.isRunning, options: [.initial, .new]) { [weak self] _, _ in
            self?.refreshSessionState()
        }
        interruptionObservation = session.observe(\.isInterrupted, options: [.initial, .new]) { [weak self] _, _ in
            self?.refreshSessionState()
        }
        runtimeErrorObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
        ) { [weak self] notification in
            let detail = (notification.userInfo?[AVCaptureSessionErrorKey] as? Error)?.localizedDescription
                ?? "The camera session stopped unexpectedly. Try again."
            DispatchQueue.main.async { self?.unavailability = .failure(detail) }
        }
    }

    deinit {
        if let runtimeErrorObserver { NotificationCenter.default.removeObserver(runtimeErrorObserver) }
    }

    private func refreshSessionState() {
        queue.async {
            let running = self.session.isRunning
            let interrupted = self.session.isInterrupted
            DispatchQueue.main.async {
                self.sessionRunning = running
                self.interrupted = interrupted
                if running && !interrupted {
                    self.unavailability = nil
                    self.setExposure(self.center)
                }
            }
        }
    }

    var captureUnavailableReason: String? {
        guard ready else { return nil }
        if maxCount < 3 { return "AEB is unavailable on this camera. Switch cameras to take a bracket." }
        if !offsets.allSatisfy({ $0 >= minBias && $0 <= maxBias }) {
            return "Reduce the EV step or center exposure to fit this camera’s range."
        }
        return nil
    }

    var offsets: [Float] {
        let half = count / 2
        return (-half...half).map { center + Float($0) * spacing }
    }

    var canCapture: Bool {
        ready && !busy && count <= maxCount && offsets.allSatisfy { $0 >= minBias && $0 <= maxBias }
    }

    func start() {
        queue.async { self.shouldRun = true }
        unavailability = nil
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.configure() }
                else { DispatchQueue.main.async { self.unavailability = .permissionDenied } }
            }
        default: unavailability = .permissionDenied
        }
    }

    func stop() {
        queue.async {
            self.shouldRun = false
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configure() {
        queue.async {
            guard self.shouldRun else { return }
            if let camera = self.device {
                if !self.session.isRunning { self.session.startRunning() }
                self.publishCapabilities(for: camera)
                return
            }
            guard let camera = self.preferredCamera(position: .back) else {
                DispatchQueue.main.async { self.unavailability = .noCamera }
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                guard self.session.canAddInput(input), self.session.canAddOutput(self.output) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.unavailability = .failure("Could not configure the camera. Try again.") }
                    return
                }
                self.session.addInput(input)
                self.session.addOutput(self.output)
                self.session.commitConfiguration()
                self.device = camera
                let activeCamera = self.bracketCompatibleCamera(camera)
                self.session.startRunning()
                self.publishCapabilities(for: activeCamera, resetZoom: true)
            } catch {
                DispatchQueue.main.async { self.unavailability = .failure("Could not start the camera: \(error.localizedDescription)") }
            }
        }
    }

    private func preferredCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInWideAngleCamera]
        for type in types {
            if let camera = AVCaptureDevice.default(type, for: .video, position: position) { return camera }
        }
        return nil
    }

    private func replaceInput(with camera: AVCaptureDevice) throws -> Bool {
        let input = try AVCaptureDeviceInput(device: camera)
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return false }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.removeInput(currentInput)
        guard session.canAddInput(input) else {
            session.addInput(currentInput)
            return false
        }
        session.addInput(input)
        device = camera
        return true
    }

    private func bracketCompatibleCamera(_ camera: AVCaptureDevice) -> AVCaptureDevice {
        guard camera.isVirtualDevice, output.maxBracketedCapturePhotoCount < 3,
              let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: camera.position)
        else { return camera }
        do {
            return try replaceInput(with: wide) ? wide : camera
        } catch {
            DispatchQueue.main.async { self.message = "Could not select a camera for AEB: \(error.localizedDescription)" }
            return camera
        }
    }

    private func publishCapabilities(for camera: AVCaptureDevice, resetZoom: Bool = false) {
        if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        let maximum = output.maxBracketedCapturePhotoCount
        let switchovers = camera.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        let includesUltraWide = camera.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }
        let scale: CGFloat = includesUltraWide ? 1 / (switchovers.first ?? 1) : 1
        zoomScale = scale
        if resetZoom {
            do {
                try camera.lockForConfiguration()
                camera.videoZoomFactor = min(max(1 / scale, camera.minAvailableVideoZoomFactor), camera.maxAvailableVideoZoomFactor)
                camera.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async { self.message = "Could not reset zoom: \(error.localizedDescription)" }
            }
        }
        let minimum = camera.minAvailableVideoZoomFactor * scale
        let zoomLimit = min(camera.maxAvailableVideoZoomFactor * scale, 10)
        let currentZoom = camera.videoZoomFactor * scale
        let presets = Array(Set(([minimum, 1, 2] + switchovers.map { $0 * scale })
            .filter { $0 >= minimum && $0 <= zoomLimit })).sorted()
        DispatchQueue.main.async {
            self.maxCount = maximum
            self.minBias = camera.minExposureTargetBias
            self.maxBias = camera.maxExposureTargetBias
            self.minZoom = minimum
            self.maxZoom = zoomLimit
            self.zoomPresets = presets
            self.zoom = currentZoom
            if self.count > maximum { self.count = 3 }
            self.setExposure(self.center)
        }
    }

    func switchCamera() {
        guard ready, !busy else { return }
        switchingCamera = true
        queue.async {
            defer {
                DispatchQueue.main.async {
                    self.switchingCamera = false
                    self.setExposure(self.center)
                }
            }
            guard self.shouldRun, let currentInput = self.session.inputs.first as? AVCaptureDeviceInput else {
                return
            }
            let position: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
            do {
                guard let camera = self.preferredCamera(position: position) else {
                    DispatchQueue.main.async { self.message = "This camera is unavailable." }
                    return
                }
                guard try self.replaceInput(with: camera) else {
                    self.publishCapabilities(for: currentInput.device)
                    DispatchQueue.main.async { self.message = "Could not switch cameras." }
                    return
                }
                let activeCamera = self.bracketCompatibleCamera(camera)
                self.publishCapabilities(for: activeCamera, resetZoom: true)
            } catch {
                DispatchQueue.main.async { self.message = "Could not switch cameras: \(error.localizedDescription)" }
            }
        }
    }

    func setZoom(_ value: CGFloat) {
        guard ready, !busy else { return }
        let target = min(max(value, minZoom), maxZoom)
        zoom = target
        queue.async {
            guard let camera = self.device else { return }
            do {
                try camera.lockForConfiguration()
                defer { camera.unlockForConfiguration() }
                camera.videoZoomFactor = min(max(target / self.zoomScale, camera.minAvailableVideoZoomFactor), camera.maxAvailableVideoZoomFactor)
            } catch {
                let actualZoom = camera.videoZoomFactor * self.zoomScale
                DispatchQueue.main.async { self.zoom = actualZoom }
            }
        }
    }

    func focus(at point: CGPoint) {
        guard ready, !busy else { return }
        queue.async {
            guard let camera = self.device else { return }
            do {
                try camera.lockForConfiguration()
                defer { camera.unlockForConfiguration() }
                if camera.isFocusPointOfInterestSupported, camera.isFocusModeSupported(.autoFocus) {
                    camera.focusPointOfInterest = point
                    camera.focusMode = .autoFocus
                }
                if camera.isExposurePointOfInterestSupported, camera.isExposureModeSupported(.continuousAutoExposure) {
                    camera.exposurePointOfInterest = point
                    camera.exposureMode = .continuousAutoExposure
                }
            } catch {
                DispatchQueue.main.async { self.message = "Could not adjust focus: \(error.localizedDescription)" }
            }
        }
    }

    func setExposure(_ value: Float) {
        guard ready, !busy else { return }
        queue.async {
            guard let camera = self.device else { return }
            do {
                try camera.lockForConfiguration()
                defer { camera.unlockForConfiguration() }
                camera.setExposureTargetBias(min(max(value, camera.minExposureTargetBias), camera.maxExposureTargetBias))
            } catch {
                DispatchQueue.main.async { self.message = "Could not adjust exposure: \(error.localizedDescription)" }
            }
        }
    }

    func capture() {
        guard canCapture else { return }
        busy = true
        lastCapture = nil
        let values = offsets
        queue.async {
            self.images = []
            self.captureError = nil
            let settings = values.map { AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettings(exposureTargetBias: $0) }
            let bracket = AVCapturePhotoBracketSettings(rawPixelFormatType: 0, processedFormat: [AVVideoCodecKey: AVVideoCodecType.jpeg], bracketedSettings: settings)
            if self.output.isLensStabilizationDuringBracketedCaptureSupported {
                bracket.isLensStabilizationEnabled = true
            }
            self.output.capturePhoto(with: bracket, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error { captureError = error.localizedDescription; return }
        if let data = photo.fileDataRepresentation() { images.append(data) }
        else { captureError = "A photo could not be processed." }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error?.localizedDescription ?? captureError {
            DispatchQueue.main.async { self.busy = false; self.message = "Capture failed: \(error)" }
            return
        }
        let photos = images
        images.removeAll()
        guard !photos.isEmpty, photos.count == resolvedSettings.expectedPhotoCount else {
            DispatchQueue.main.async { self.busy = false; self.message = "The exposure bracket was incomplete. Please try again." }
            return
        }
        let previews = photos.compactMap { data in
            UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 1600, height: 1600))
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { self.busy = false; self.message = "Allow Photos access in Settings to save your bracket." }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                for data in photos {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, data: data, options: nil)
                }
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    self.busy = false
                    if success {
                        self.recentPhotos = previews
                        self.lastCapture = "Saved \(photos.count) exposures"
                    }
                    else { self.message = "Could not save photos: \(error?.localizedDescription ?? "Unknown error")" }
                }
            }
        }
    }
}
