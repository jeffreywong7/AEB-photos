import SwiftUI
import AVFoundation

private let cameraYellow = Color(red: 1, green: 0.83, blue: 0)

struct CameraView: View {
    @StateObject private var camera = CameraModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var controlsExpanded = false
    @State private var reviewingPhotos = false
    @State private var focusPoint: CGPoint?
    @State private var focusTask: Task<Void, Never>?
    @State private var zoomStart: CGFloat?
    @State private var exposureDragStart: Float?

    var body: some View {
        GeometryReader { geometry in
            let previewHeight = geometry.size.width * 4 / 3
            let compact = geometry.size.height < previewHeight + 224
            VStack(spacing: 0) {
                if !compact {
                    toolbar.frame(height: 52)
                    Spacer(minLength: 0)
                }
                viewfinder.frame(width: geometry.size.width, height: previewHeight)
                Spacer(minLength: 0)
                bottomControls.frame(height: compact ? max(116, geometry.size.height - previewHeight) : 172)
            }
            .overlay(alignment: .top) {
                if compact { toolbar.background(.black.opacity(0.25)) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear { updateCameraActivity() }
        .task(id: camera.lastCapture) {
            guard camera.lastCapture != nil else { return }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { camera.lastCapture = nil }
        }
        .onChange(of: camera.center) { camera.setExposure($0) }
        .onChange(of: scenePhase) { _ in updateCameraActivity() }
        .onChange(of: reviewingPhotos) { _ in updateCameraActivity() }
        .onDisappear { focusTask?.cancel(); camera.stop() }
        .fullScreenCover(isPresented: $reviewingPhotos) { photoReview }
        .alert("Camera", isPresented: Binding(get: { camera.message != nil }, set: { if !$0 { camera.message = nil } })) {
            Button("OK", role: .cancel) { camera.message = nil }
        } message: { Text(camera.message ?? "") }
    }

    private var toolbar: some View {
        HStack {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .accessibilityLabel("Flash off during exposure bracketing")
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { controlsExpanded.toggle() }
            } label: {
                Image(systemName: controlsExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.12), in: Circle())
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(controlsExpanded ? "Hide camera controls" : "Show camera controls")
            .accessibilityValue(controlsExpanded ? "Expanded" : "Collapsed")
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { controlsExpanded.toggle() }
            } label: {
                Text("AEB")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(cameraYellow)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(cameraYellow, lineWidth: 1))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Auto exposure bracketing settings")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
    }

    private var viewfinder: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(session: camera.session) { point, devicePoint in
                    guard camera.ready, !camera.busy else { return }
                    camera.focus(at: devicePoint)
                    displayFocus(at: point)
                }
                .simultaneousGesture(MagnificationGesture()
                    .onChanged { value in
                        if zoomStart == nil { zoomStart = camera.zoom }
                        camera.setZoom((zoomStart ?? 1) * value)
                    }
                    .onEnded { _ in zoomStart = nil })
                .simultaneousGesture(DragGesture(minimumDistance: 35)
                    .onEnded { value in
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }
                        withAnimation(.easeInOut(duration: 0.22)) { controlsExpanded = value.translation.height < 0 }
                    })
                if camera.showGrid {
                    GridOverlay().stroke(.white.opacity(0.35), lineWidth: 0.5).allowsHitTesting(false)
                }
                if let focusPoint {
                    focusIndicator(at: focusPoint, in: geometry.size)
                }
                if !camera.ready {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill").font(.system(size: 30, weight: .light))
                        Text("Camera unavailable").font(.system(size: 14))
                        Text("Allow camera access and use a physical iPhone.")
                            .font(.system(size: 12)).multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white.opacity(0.6)).padding(24)
                }
                VStack {
                    if let status = camera.lastCapture {
                        Text(status)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(.top, 16)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    Spacer()
                    if controlsExpanded {
                        aebControls.transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        zoomControls.padding(.bottom, 18)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(white: 0.08))
            .clipped()
        }
    }

    private func focusIndicator(at point: CGPoint, in size: CGSize) -> some View {
        let x = min(max(point.x, 36), size.width - 36)
        let y = min(max(point.y, 50), size.height - 50)
        let sunOnLeft = x > size.width - 80
        return HStack(spacing: 8) {
            if sunOnLeft { exposureControl }
            Rectangle().stroke(cameraYellow, lineWidth: 1)
                .frame(width: 72, height: 72)
                .allowsHitTesting(false)
            if !sunOnLeft { exposureControl }
        }
        .position(x: x + (sunOnLeft ? -20 : 20), y: y)
    }

    private var exposureControl: some View {
        Image(systemName: "sun.max.fill")
            .font(.system(size: 18))
            .foregroundStyle(cameraYellow)
            .frame(width: 32, height: 100)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 1)
                .onChanged { value in
                    guard camera.ready, !camera.busy else { return }
                    focusTask?.cancel()
                    if exposureDragStart == nil { exposureDragStart = camera.center }
                    let exposure = (exposureDragStart ?? 0) - Float(value.translation.height / 80)
                    camera.center = min(max((exposure * 2).rounded() / 2, -2), 2)
                }
                .onEnded { _ in
                    exposureDragStart = nil
                    if let point = focusPoint { displayFocus(at: point) }
                })
            .accessibilityLabel("Exposure")
            .accessibilityValue("\(ev(camera.center)) EV")
            .accessibilityAdjustableAction { direction in
                guard camera.ready, !camera.busy else { return }
                switch direction {
                case .increment: camera.center = min(camera.center + 0.5, 2)
                case .decrement: camera.center = max(camera.center - 0.5, -2)
                @unknown default: break
                }
            }
    }

    private func displayFocus(at point: CGPoint) {
        focusTask?.cancel()
        focusPoint = point
        focusTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { focusPoint = nil }
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 12) {
            ForEach(camera.zoomPresets, id: \.self) { value in
                Button { camera.setZoom(value) } label: {
                    Text(isSelectedZoom(value) ? "\(zoomLabel(camera.zoom))×" : zoomLabel(value))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelectedZoom(value) ? cameraYellow : .white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.55), in: Circle())
                }
                .accessibilityLabel("\(zoomLabel(value)) times zoom")
                .accessibilityAddTraits(isSelectedZoom(value) ? .isSelected : [])
                .disabled(!camera.ready || camera.busy)
            }
        }
        .padding(4)
        .background(.black.opacity(0.25), in: Capsule())
    }

    private var aebControls: some View {
        VStack(spacing: 16) {
            HStack {
                Text("AEB").foregroundStyle(cameraYellow)
                Spacer()
                Button { camera.showGrid.toggle() } label: {
                    Image(systemName: "grid")
                        .foregroundStyle(camera.showGrid ? cameraYellow : .white)
                        .frame(width: 44, height: 44)
                }.accessibilityLabel(camera.showGrid ? "Hide grid" : "Show grid")
            }.font(.system(size: 14, weight: .semibold))
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 8) {
                    settingLabel("FRAMES")
                    Picker("Bracket frames", selection: $camera.count) {
                        Text("3").tag(3)
                        if camera.maxCount >= 5 { Text("5").tag(5) }
                    }.pickerStyle(.segmented)
                }
                VStack(spacing: 8) {
                    settingLabel("EV STEP")
                    Picker("Exposure step", selection: $camera.spacing) {
                        Text("½").tag(Float(0.5))
                        Text("1").tag(Float(1))
                        Text("2").tag(Float(2))
                    }.pickerStyle(.segmented)
                }
            }
            HStack(spacing: 12) {
                Image(systemName: "plusminus.circle").font(.system(size: 20))
                Slider(value: $camera.center, in: -2...2, step: 0.5)
                    .tint(cameraYellow)
                    .accessibilityLabel("Center exposure")
                    .accessibilityValue("\(ev(camera.center)) EV")
                Text(ev(camera.center)).monospacedDigit().frame(width: 42, alignment: .trailing)
            }.font(.system(size: 14))
            HStack(spacing: 0) {
                ForEach(Array(camera.offsets.enumerated()), id: \.offset) { index, value in
                    Text(ev(value))
                        .foregroundStyle(index == camera.count / 2 ? cameraYellow : .white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                }
                Text("EV").foregroundStyle(.white.opacity(0.5))
            }.font(.system(size: 12, weight: .medium, design: .monospaced))
            if let reason = camera.captureUnavailableReason {
                Text(reason).font(.system(size: 12)).foregroundStyle(cameraYellow).multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
        .background(.black.opacity(0.85))
        .disabled(camera.busy)
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            Text("PHOTO")
                .font(.system(size: 13, weight: .semibold)).tracking(1)
                .foregroundStyle(cameraYellow).frame(height: 26)
            HStack {
                Button { reviewingPhotos = true } label: {
                    Group {
                        if let thumbnail = camera.recentPhotos.first {
                            Image(uiImage: thumbnail).resizable().scaledToFill()
                        } else {
                            RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.12))
                                .overlay(Image(systemName: "photo").foregroundStyle(.white.opacity(0.45)))
                        }
                    }
                    .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .disabled(camera.recentPhotos.isEmpty)
                .accessibilityLabel("Review last exposure bracket")
                Spacer()
                Button { camera.capture() } label: {
                    ZStack {
                        Circle().stroke(.white, lineWidth: 4).frame(width: 78, height: 78)
                        Circle().fill(.white).frame(width: 66, height: 66)
                        if camera.busy { ProgressView().tint(.black) }
                    }.opacity(camera.canCapture || camera.busy ? 1 : 0.45)
                }
                .buttonStyle(ShutterButtonStyle())
                .disabled(!camera.canCapture)
                .accessibilityLabel("Take exposure bracket")
                .accessibilityValue(camera.busy ? "Saving photos" : "\(camera.count) photos, \(camera.spacing) EV spacing")
                Spacer()
                Button { camera.switchCamera() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .disabled(!camera.ready || camera.busy)
                .accessibilityLabel("Switch camera")
            }.padding(.horizontal, 30)
            if !controlsExpanded, let reason = camera.captureUnavailableReason {
                Text(reason).font(.system(size: 11)).foregroundStyle(cameraYellow).multilineTextAlignment(.center)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var photoReview: some View {
        NavigationStack {
            TabView {
                ForEach(camera.recentPhotos.indices, id: \.self) { index in
                    Image(uiImage: camera.recentPhotos[index])
                        .resizable().scaledToFit()
                        .accessibilityLabel("Exposure \(index + 1) of \(camera.recentPhotos.count)")
                }
            }
            .tabViewStyle(.page)
            .background(.black)
            .navigationTitle("Last Bracket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { reviewingPhotos = false }.tint(cameraYellow)
                }
            }
        }.preferredColorScheme(.dark)
    }

    private func settingLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.white.opacity(0.6))
    }

    private func ev(_ value: Float) -> String { value == 0 ? "0" : String(format: "%+.1f", value) }
    private func zoomLabel(_ value: CGFloat) -> String {
        String(format: abs(value - value.rounded()) < 0.05 ? "%.0f" : "%.1f", Double(value))
    }

    private func isSelectedZoom(_ value: CGFloat) -> Bool {
        let selected = camera.zoomPresets.last(where: { $0 <= camera.zoom + 0.01 }) ?? camera.minZoom
        return value == selected
    }

    private func updateCameraActivity() {
        if scenePhase == .active && !reviewingPhotos { camera.start() }
        else { camera.stop() }
    }
}

private struct ShutterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onFocus: (CGPoint, CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onFocus = onFocus
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) { view.onFocus = onFocus }

    final class PreviewView: UIView {
        var onFocus: ((CGPoint, CGPoint) -> Void)?
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        override init(frame: CGRect) {
            super.init(frame: frame)
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focus(_:))))
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }

        @objc private func focus(_ gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: self)
            onFocus?(point, previewLayer.captureDevicePointConverted(fromLayerPoint: point))
        }
    }
}

struct GridOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for fraction in [CGFloat(1.0 / 3.0), CGFloat(2.0 / 3.0)] {
            path.move(to: CGPoint(x: rect.width * fraction, y: 0))
            path.addLine(to: CGPoint(x: rect.width * fraction, y: rect.height))
            path.move(to: CGPoint(x: 0, y: rect.height * fraction))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * fraction))
        }
        return path
    }
}
