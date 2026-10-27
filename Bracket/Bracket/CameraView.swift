import SwiftUI
import AVFoundation

private let cameraYellow = Color(uiColor: .systemYellow)

struct CameraView: View {
    @StateObject private var camera = CameraModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    private enum CameraPanel: String, CaseIterable {
        case bracketing = "AEB"
        case exposure = "Exposure"
        case timer = "Timer"
        case grid = "Grid"
    }

    @State private var selectedPanel: CameraPanel?
    @State private var reviewingPhotos = false
    @State private var focusPoint: CGPoint?
    @State private var focusTask: Task<Void, Never>?
    @State private var zoomStart: CGFloat?
    @State private var exposureDragStart: Float?
    @State private var showingZoomWheel = false
    @State private var mainLensMM: Int?
    @State private var wheelStartZoom: CGFloat?
    @State private var timerSeconds = 0
    @State private var countdown: Int?
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            let top = geometry.safeAreaInsets.top
            let bottom = geometry.safeAreaInsets.bottom
            let size = CGSize(width: geometry.size.width, height: geometry.size.height + top + bottom)
            let layout = CameraLayout(size: size, safeTop: top, safeBottom: bottom)
            ZStack {
                Color.black
                viewfinder
                    .frame(width: layout.previewFrame.width, height: layout.previewFrame.height)
                    .position(x: layout.previewFrame.midX, y: layout.previewFrame.midY)
                toolbar.position(layout.toolbarCenter)
                ZStack {
                    shutterRow.position(layout.shutterCenter)
                    footerRow.position(layout.footerCenter)
                }.cameraGlassGroup()
            }
            .frame(width: size.width, height: size.height)
            .offset(y: -top)
        }
        .background(.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            camera.start()
            #if DEBUG
            if camera.isInterfacePreview {
                switch CameraInterfacePreview.state {
                case "aeb": selectedPanel = .bracketing
                case "wheel": showingZoomWheel = true; camera.setZoom(0.7)
                case "focal": mainLensMM = 35; camera.setZoom(CGFloat(35) / 24)
                case "timer": selectedPanel = .timer; timerSeconds = 3
                default: break
                }
            }
            #endif
        }
        .cameraSnapshotPreview()
        .task(id: camera.lastCapture) {
            guard camera.lastCapture != nil else { return }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { camera.lastCapture = nil }
        }
        .onChange(of: camera.center) { camera.setExposure($0) }
        .onChange(of: camera.zoom) { zoom in
            if let mm = mainLensMM, abs(zoom - CGFloat(mm) / 24) > 0.01 { mainLensMM = nil }
        }
        .onChange(of: camera.ready) { ready in
            if !ready { showingZoomWheel = false; mainLensMM = nil; cancelCountdown() }
        }
        .onChange(of: scenePhase) { _ in updateCameraActivity() }
        .onChange(of: reviewingPhotos) { _ in updateCameraActivity() }
        .onDisappear { focusTask?.cancel(); cancelCountdown(); camera.stop() }
        .fullScreenCover(isPresented: $reviewingPhotos) { photoReview }
        .alert("Camera", isPresented: Binding(get: { camera.message != nil }, set: { if !$0 { camera.message = nil } })) {
            Button("OK", role: .cancel) { camera.message = nil }
        } message: { Text(camera.message ?? "") }
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            flashControl
            Image(systemName: "livephoto.slash")
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Live Photos off")
            Button { togglePanel(.exposure) } label: {
                VStack(spacing: -1) {
                    Text(String(format: "%.1f", camera.center)).font(.system(size: 15, weight: .regular)).monospacedDigit()
                    Text("EV").font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(camera.center == 0 ? .white : cameraYellow)
                .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Exposure adjustment")
            .accessibilityValue("\(ev(camera.center)) EV")
        }
        .fixedSize()
        .disabled(camera.busy || countdown != nil)
    }

    private var flashControl: some View {
        Menu {
            if camera.aebEnabled {
                Text("Flash is unavailable with AEB")
                ForEach([AVCaptureDevice.FlashMode.auto, .on], id: \.rawValue) { mode in
                    if camera.supportedFlashModes.contains(mode) {
                        Button("Use Flash \(mode == .auto ? "Auto" : "On") (AEB Off)") {
                            camera.flashMode = mode
                            camera.aebEnabled = false
                        }
                    }
                }
            } else {
                Picker("Flash", selection: $camera.flashMode) {
                    Text("Off").tag(AVCaptureDevice.FlashMode.off)
                    if camera.supportedFlashModes.contains(.auto) { Text("Auto").tag(AVCaptureDevice.FlashMode.auto) }
                    if camera.supportedFlashModes.contains(.on) { Text("On").tag(AVCaptureDevice.FlashMode.on) }
                }
            }
        } label: {
            Image(systemName: camera.aebEnabled || camera.flashMode == .off ? "bolt.slash.fill" : "bolt.fill")
                .font(.system(size: 20))
                .foregroundStyle(!camera.aebEnabled && camera.flashMode != .off ? cameraYellow : .white)
                .frame(width: 44, height: 44)
        }
        .disabled(!camera.ready || camera.busy)
        .accessibilityLabel("Flash")
        .accessibilityValue(camera.aebEnabled ? "Off during AEB" : camera.flashMode == .auto ? "Auto" : camera.flashMode == .on ? "On" : "Off")
    }

    private var cameraPreview: some View {
        CameraPreview(session: camera.session) { point, devicePoint in
            guard camera.ready, !camera.busy, countdown == nil else { return }
            if selectedPanel != nil { selectedPanel = nil; return }
            if showingZoomWheel { showingZoomWheel = false; return }
            camera.focus(at: devicePoint)
            displayFocus(at: point)
        }
    }

    private var viewfinder: some View {
        GeometryReader { geometry in
            ZStack {
                Group {
                    #if DEBUG
                    if camera.isInterfacePreview { CameraPreviewScene() }
                    else { cameraPreview }
                    #else
                    cameraPreview
                    #endif
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
                        withAnimation(.easeInOut(duration: 0.22)) {
                            selectedPanel = value.translation.height < 0 ? .bracketing : nil
                            showingZoomWheel = false
                        }
                    })
                if camera.showGrid {
                    GridOverlay().stroke(.white.opacity(0.35), lineWidth: 0.5).allowsHitTesting(false)
                }
                if let focusPoint {
                    focusIndicator(at: focusPoint, in: geometry.size)
                }
                if !camera.ready { cameraStatus }
                if let countdown {
                    Text("\(countdown)")
                        .font(.system(size: 80, weight: .thin))
                        .foregroundStyle(.white)
                        .shadow(radius: 8)
                        .accessibilityLabel("Taking photo in \(countdown) seconds")
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
                    if selectedPanel != nil {
                        cameraControls.transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        zoomInterface
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(white: 0.08))
            .clipped()
        }
    }

    @ViewBuilder
    private var cameraStatus: some View {
        if camera.interrupted {
            statusMessage(title: "Camera interrupted", detail: "The camera will resume when it becomes available.")
        } else if let reason = camera.unavailability {
            VStack(spacing: 16) {
                switch reason {
                case .permissionDenied:
                    statusMessage(title: "Camera access disabled", detail: "Allow camera access for Bracket in Settings.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                case .noCamera:
                    statusMessage(title: "No camera available", detail: "This device does not have an accessible camera.")
                case .failure(let detail):
                    statusMessage(title: "Camera unavailable", detail: detail)
                    Button("Try Again") { camera.start() }
                }
            }
            .tint(cameraYellow)
            .padding(20)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            .padding(24)
        } else {
            ProgressView("Starting camera…")
                .tint(.white)
                .foregroundStyle(.white)
                .padding(20)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func statusMessage(title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill").font(.system(size: 30, weight: .light))
            Text(title).font(.system(size: 14, weight: .semibold))
            Text(detail).font(.system(size: 12)).multilineTextAlignment(.center)
        }.foregroundStyle(.white)
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

    private var zoomInterface: some View {
        ZStack(alignment: .bottom) {
            if showingZoomWheel {
                ZoomWheel(zoom: camera.zoom, limits: camera.minZoom...camera.maxZoom, stops: camera.zoomPresets, mainFocalLength: camera.rearCamera ? 24 : nil,
                          onZoom: camera.setZoom, onClose: { showingZoomWheel = false })
            } else {
                zoomControls.padding(.bottom, 18)
            }
        }
        .frame(height: showingZoomWheel ? 134 : 66)
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard camera.ready, !camera.busy else { return }
                if wheelStartZoom == nil { wheelStartZoom = camera.zoom }
                showingZoomWheel = true
                camera.setZoom((wheelStartZoom ?? camera.zoom) * CGFloat(pow(2, -Double(value.translation.width) / 140)))
            }
            .onEnded { _ in wheelStartZoom = nil })
        .disabled(!camera.ready || camera.busy)
    }

    private var zoomControls: some View {
        let mainIndex = camera.zoomPresets.firstIndex(of: 1) ?? 0
        let offset = (CGFloat(camera.zoomPresets.count - 1) / 2 - CGFloat(mainIndex)) * 40
        return HStack(spacing: 0) {
            ForEach(camera.zoomPresets, id: \.self) { value in
                Button {
                    guard !showingZoomWheel else { return }
                    if value == 1, isSelectedZoom(1), camera.rearCamera {
                        let options = [24, 28, 35].filter { CGFloat($0) / 24 <= camera.maxZoom }
                        let index = options.firstIndex(of: mainLensMM ?? 24) ?? 0
                        let mm = options[(index + 1) % options.count]
                        mainLensMM = mm
                        camera.setZoom(CGFloat(mm) / 24)
                    } else {
                        mainLensMM = nil
                        camera.setZoom(value)
                    }
                } label: {
                    Group {
                        if value == 1, isSelectedZoom(1), let mm = mainLensMM {
                            VStack(spacing: -2) {
                                Text("\(mm)").font(.system(size: 14, weight: .semibold))
                                Text("MM").font(.system(size: 9, weight: .medium))
                            }
                        } else {
                            Text(isSelectedZoom(value) ? "\(zoomLabel(camera.zoom))×" : value == 0.5 ? ".5" : zoomLabel(value))
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .foregroundStyle(isSelectedZoom(value) ? cameraYellow : .white)
                    .frame(width: 40, height: 40)
                    .background(isSelectedZoom(value) ? Color(white: 0.18).opacity(0.8) : .clear, in: Circle())
                }
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in showingZoomWheel = true })
                .accessibilityLabel(value == 1 && camera.rearCamera ? "Main camera. Tap to cycle 24, 28, and 35 millimeters" : "\(zoomLabel(value)) times zoom")
                .accessibilityHint("Touch and hold to open the zoom wheel")
                .accessibilityAddTraits(isSelectedZoom(value) ? .isSelected : [])
                .disabled(!camera.ready || camera.busy)
            }
        }
        .offset(x: offset)
    }

    private var cameraControls: some View {
        VStack(spacing: 16) {
            HStack {
                ForEach(CameraPanel.allCases, id: \.self) { panel in
                    Button { selectedPanel = panel } label: {
                        Text(panel.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(selectedPanel == panel ? cameraYellow : .white.opacity(0.7))
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .accessibilityAddTraits(selectedPanel == panel ? .isSelected : [])
                }
                Button { selectedPanel = nil } label: {
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).frame(width: 36, height: 36)
                }.accessibilityLabel("Close camera controls")
            }
            switch selectedPanel {
            case .bracketing: aebControls
            case .exposure: exposureSettings
            case .timer: timerSettings
            case .grid:
                Toggle("Grid", isOn: $camera.showGrid).tint(cameraYellow).padding(.horizontal, 20)
            case nil: EmptyView()
            }
        }
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 20)
        .foregroundStyle(.white)
        .background(.ultraThinMaterial)
        .disabled(camera.busy || countdown != nil)
    }

    private var exposureSettings: some View {
        HStack(spacing: 16) {
            Image(systemName: "plusminus.circle").font(.system(size: 20))
            Slider(value: $camera.center, in: -2...2, step: 0.5).tint(cameraYellow)
                .accessibilityLabel("Center exposure")
            Text(ev(camera.center)).monospacedDigit().frame(width: 42)
        }.padding(.horizontal, 20)
    }

    private var timerSettings: some View {
        HStack(spacing: 12) {
            ForEach([0, 3, 5, 10], id: \.self) { seconds in
                Button { timerSeconds = seconds } label: {
                    Text(seconds == 0 ? "Off" : "\(seconds)s")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(timerSeconds == seconds ? .black : .white)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(timerSeconds == seconds ? cameraYellow : .white.opacity(0.1), in: Capsule())
                }
                .accessibilityLabel(seconds == 0 ? "Timer off" : "\(seconds) second timer")
                .accessibilityAddTraits(timerSeconds == seconds ? .isSelected : [])
            }
        }.padding(.horizontal, 12)
    }

    private var aebControls: some View {
        VStack(spacing: 16) {
            HStack {
                Toggle("AEB", isOn: $camera.aebEnabled).tint(cameraYellow)
                Spacer().frame(width: 20)
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
            }.disabled(!camera.aebEnabled).opacity(camera.aebEnabled ? 1 : 0.4)
            HStack(spacing: 12) {
                Image(systemName: "plusminus.circle").font(.system(size: 20))
                Slider(value: $camera.center, in: -2...2, step: 0.5)
                    .tint(cameraYellow)
                    .accessibilityLabel("Center exposure")
                    .accessibilityValue("\(ev(camera.center)) EV")
                Text(ev(camera.center)).monospacedDigit().frame(width: 42, alignment: .trailing)
            }.font(.system(size: 14))
            if camera.aebEnabled {
                HStack(spacing: 0) {
                    ForEach(Array(camera.offsets.enumerated()), id: \.offset) { index, value in
                        Text(ev(value))
                            .foregroundStyle(index == camera.count / 2 ? cameraYellow : .white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                    }
                    Text("EV").foregroundStyle(.white.opacity(0.5))
                }.font(.system(size: 12, weight: .medium, design: .monospaced))
                Text("Flash is off during AEB")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            }
            if let reason = camera.captureUnavailableReason {
                Text(reason).font(.system(size: 12)).foregroundStyle(cameraYellow).multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 12)
        .disabled(camera.busy)
    }

    private var shutterRow: some View {
        HStack {
            Button { togglePanel(.bracketing) } label: {
                Text("AEB")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(camera.aebEnabled ? cameraYellow : .white)
                    .frame(width: 48, height: 48)
                    .cameraGlass(in: Circle())
            }
            .accessibilityLabel("Auto exposure bracketing settings")
            .accessibilityValue(camera.aebEnabled ? "On" : "Off")
            .disabled(camera.busy || countdown != nil)
            Spacer()
            Button(action: pressShutter) {
                ZStack {
                    Circle().fill(Color(white: 0.11)).frame(width: 82, height: 82)
                    Circle().stroke(.white.opacity(0.25), lineWidth: 1).frame(width: 80, height: 80)
                    Circle().fill(.white).frame(width: 70, height: 70)
                    if countdown != nil {
                        Image(systemName: "xmark").font(.system(size: 20, weight: .medium)).foregroundStyle(.black)
                    } else if camera.busy {
                        ProgressView().tint(.black)
                    }
                }.opacity(camera.canCapture || camera.busy || countdown != nil ? 1 : 0.45)
            }
            .buttonStyle(ShutterButtonStyle())
            .disabled(!camera.canCapture && countdown == nil)
            .accessibilityIdentifier("camera.shutter")
            .accessibilityLabel(countdown != nil ? "Cancel timer" : camera.aebEnabled ? "Take exposure bracket" : "Take photo")
            .accessibilityValue(camera.busy ? "Saving photos" : camera.aebEnabled ? "\(camera.count) photos" : "Single photo")
            Spacer()
            Button { togglePanel(selectedPanel ?? .bracketing) } label: {
                VStack(spacing: 3) {
                    ForEach(0..<2, id: \.self) { _ in
                        HStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { _ in Circle().frame(width: 4.5, height: 4.5) }
                        }
                    }
                }
                .foregroundStyle(selectedPanel == nil ? .white : cameraYellow)
                .frame(width: 48, height: 48)
                .cameraGlass(in: Circle())
            }
            .accessibilityLabel(selectedPanel == nil ? "Show camera controls" : "Hide camera controls")
            .disabled(camera.busy || countdown != nil)
        }
        .padding(.horizontal, 34)
        .frame(height: 82)
    }

    private var footerRow: some View {
        HStack {
            Button { reviewingPhotos = true } label: {
                Group {
                    if let thumbnail = camera.recentPhotos.first {
                        Image(uiImage: thumbnail).resizable().scaledToFill()
                    } else {
                        Circle().fill(Color(white: 0.13))
                            .overlay(Image(systemName: "photo").font(.system(size: 19)).foregroundStyle(.white.opacity(0.5)))
                    }
                }
                .frame(width: 48, height: 48).clipShape(Circle())
            }
            .disabled(camera.recentPhotos.isEmpty || camera.busy || countdown != nil)
            .accessibilityLabel("Review last capture")
            Spacer()
            Text("PHOTO")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(cameraYellow)
                .frame(width: 92, height: 44)
                .cameraGlass(in: Capsule())
                .accessibilityAddTraits(.isSelected)
            Spacer()
            Button { camera.switchCamera() } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 23, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .cameraGlass(in: Circle())
            }
            .disabled(!camera.ready || camera.busy || countdown != nil)
            .accessibilityLabel("Switch camera")
        }
        .padding(.horizontal, 34)
        .frame(height: 48)
    }

    private func togglePanel(_ panel: CameraPanel) {
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedPanel = selectedPanel == panel ? nil : panel
            showingZoomWheel = false
        }
    }

    private func pressShutter() {
        if countdown != nil { cancelCountdown(); return }
        guard camera.canCapture else { return }
        selectedPanel = nil
        showingZoomWheel = false
        guard timerSeconds > 0 else { camera.capture(); return }
        countdown = timerSeconds
        timerTask = Task { @MainActor in
            do {
                for remaining in stride(from: timerSeconds, through: 1, by: -1) {
                    countdown = remaining
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
                guard !Task.isCancelled else { return }
                countdown = nil
                timerTask = nil
                guard camera.canCapture, scenePhase == .active else { return }
                camera.capture()
            } catch { return }
        }
    }

    private func cancelCountdown() {
        timerTask?.cancel()
        timerTask = nil
        countdown = nil
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
            .navigationTitle("Last Capture")
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
        if scenePhase != .active { cancelCountdown() }
        if reviewingPhotos || scenePhase == .background { camera.stop() }
        else if scenePhase == .active { camera.start() }
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
