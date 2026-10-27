import AVFoundation
import Photos
import SwiftUI

final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "camera.session")
    private var device: AVCaptureDevice?
    private var images: [Data] = []
    private var captureError: String?

    @Published var ready = false
    @Published var busy = false
    @Published var message: String?
    @Published var maxCount = 0
    @Published var minBias: Float = -2
    @Published var maxBias: Float = 2
    @Published var count = 3
    @Published var spacing: Float = 1
    @Published var center: Float = 0
    @Published var showGrid = true
    @Published var lastCapture: String?

    var offsets: [Float] {
        let half = count / 2
        return (-half...half).map { center + Float($0) * spacing }
    }

    var canCapture: Bool {
        ready && !busy && count <= maxCount && offsets.allSatisfy { $0 >= minBias && $0 <= maxBias }
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.configure() }
                else { DispatchQueue.main.async { self.message = "Camera access is needed to take photos. Enable it in Settings." } }
            }
        default: message = "Camera access is needed to take photos. Enable it in Settings."
        }
    }

    private func configure() {
        queue.async {
            guard !self.session.isRunning else { return }
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                DispatchQueue.main.async { self.message = "A rear camera is required. Try this app on an iPhone." }
                return
            }
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                guard self.session.canAddInput(input), self.session.canAddOutput(self.output) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.message = "Could not configure the camera." }
                    return
                }
                self.session.addInput(input)
                self.session.addOutput(self.output)
                self.session.commitConfiguration()
                self.device = camera
                self.session.startRunning()
                if let connection = self.output.connection(with: .video), connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                let maximum = self.output.maxBracketedCapturePhotoCount
                DispatchQueue.main.async {
                    self.maxCount = maximum
                    self.minBias = camera.minExposureTargetBias
                    self.maxBias = camera.maxExposureTargetBias
                    self.ready = maximum >= 3
                    if maximum < 3 { self.message = "This camera does not support a three-photo exposure bracket." }
                }
            } catch {
                DispatchQueue.main.async { self.message = "Could not start the camera: \(error.localizedDescription)" }
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
        guard !photos.isEmpty else {
            DispatchQueue.main.async { self.busy = false; self.message = "No photos were captured." }
            return
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
                    if success { self.lastCapture = "Saved \(photos.count) exposures to Photos" }
                    else { self.message = "Could not save photos: \(error?.localizedDescription ?? "Unknown error")" }
                }
            }
        }
    }
}
