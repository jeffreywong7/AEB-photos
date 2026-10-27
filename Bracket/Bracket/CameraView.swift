import SwiftUI
import AVFoundation

private let accent = Color(red: 0.82, green: 0.95, blue: 0.44)

struct CameraView: View {
    @StateObject private var camera = CameraModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.055, green: 0.065, blue: 0.055).ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    viewfinder
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 16)
                    controls
                }
                .padding(.top, 8)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom == 0 ? 12 : 0, 0))
            }
        }
        .preferredColorScheme(.dark)
        .task { camera.start() }
        .alert("Camera", isPresented: Binding(get: { camera.message != nil }, set: { if !$0 { camera.message = nil } })) {
            Button("OK", role: .cancel) { camera.message = nil }
        } message: { Text(camera.message ?? "") }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Image(systemName: "square.stack.3d.up.fill").foregroundStyle(accent)
                    Text("BRACKET").tracking(2.5)
                }.font(.system(size: 15, weight: .bold, design: .rounded))
                Text("EXPOSURE STUDIO").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(camera.ready ? accent : .gray).frame(width: 6, height: 6)
                Text(camera.ready ? "CAMERA READY" : "CAMERA OFFLINE")
                    .font(.system(size: 9, weight: .bold)).tracking(1)
            }.foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 22).padding(.bottom, 16)
    }

    private var viewfinder: some View {
        ZStack {
            CameraPreview(session: camera.session)
            if !camera.ready {
                VStack(spacing: 10) {
                    Image(systemName: "camera.aperture").font(.system(size: 36, weight: .ultraLight))
                    Text("YOUR FRAME AWAITS").font(.system(size: 10, weight: .semibold)).tracking(2)
                }.foregroundStyle(.white.opacity(0.35))
            }
            if camera.showGrid {
                GridOverlay().stroke(.white.opacity(0.23), lineWidth: 0.5).allowsHitTesting(false)
            }
            VStack {
                HStack {
                    Label("LIVE VIEW", systemImage: "circle.fill")
                        .font(.system(size: 9, weight: .bold)).tracking(1)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Button { camera.showGrid.toggle() } label: {
                        Image(systemName: "grid").font(.system(size: 15)).foregroundStyle(camera.showGrid ? accent : .white)
                            .frame(width: 34, height: 34).background(.black.opacity(0.35), in: Circle())
                    }.accessibilityLabel(camera.showGrid ? "Hide grid" : "Show grid")
                }
                Spacer()
                HStack {
                    Text("WIDE  ·  1×")
                    Spacer()
                    Text("AEB  /  \(camera.count) FRAMES")
                }.font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1).foregroundStyle(.white.opacity(0.85))
            }.padding(14)
        }
        .background(Color(red: 0.12, green: 0.14, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12)))
    }

    private var controls: some View {
        VStack(spacing: 15) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("EXPOSURE BRACKETING").font(.system(size: 9, weight: .bold)).tracking(1.7).foregroundStyle(accent)
                    Text("Set your range").font(.system(size: 20, weight: .medium, design: .serif))
                }
                Spacer()
                Text("AUTO EXPOSURE").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(.white.opacity(0.4))
            }
            HStack(spacing: 8) {
                setting(title: "FRAMES", value: "\(camera.count)") {
                    camera.count = camera.count == 3 && camera.maxCount >= 5 ? 5 : 3
                }
                setting(title: "STEP", value: String(format: "%.1f EV", camera.spacing)) {
                    camera.spacing = camera.spacing == 0.5 ? 1 : camera.spacing == 1 ? 2 : 0.5
                }
                setting(title: "CENTER", value: ev(camera.center)) {
                    camera.center = camera.center >= 1 ? -1 : camera.center + 0.5
                }
            }
            VStack(spacing: 8) {
                HStack {
                    Text("EXPOSURE SEQUENCE").font(.system(size: 9, weight: .bold)).tracking(1.3).foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Text("EV").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.45))
                }
                HStack(spacing: 4) {
                    ForEach(Array(camera.offsets.enumerated()), id: \.offset) { _, value in
                        Text(ev(value)).font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(value == camera.center ? Color.black : .white.opacity(0.75))
                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                            .background(value == camera.center ? accent : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                if camera.ready && !camera.canCapture && !camera.busy {
                    Text("Adjust the range to fit this camera’s exposure limits.").font(.caption2).foregroundStyle(.orange)
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(camera.lastCapture ?? "READY WHEN YOU ARE")
                        .font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(camera.lastCapture == nil ? .white.opacity(0.45) : accent)
                    Text("Photos save individually").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button { camera.capture() } label: {
                    ZStack {
                        Circle().stroke(.white.opacity(0.8), lineWidth: 2).frame(width: 66, height: 66)
                        Circle().fill(camera.canCapture ? accent : Color.gray).frame(width: 54, height: 54)
                        if camera.busy { ProgressView().tint(.black) }
                        else { Image(systemName: "camera.fill").font(.system(size: 19)).foregroundStyle(.black) }
                    }
                }.disabled(!camera.canCapture).accessibilityLabel("Capture exposure bracket")
                Spacer().frame(width: 34)
            }
        }.padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 12)
    }

    private func setting(title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(title).font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
                }
                Text(value).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
        }.accessibilityLabel("\(title), \(value). Tap to change")
    }

    private func ev(_ value: Float) -> String { value == 0 ? "0" : String(format: "%+.1f", value) }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) {}
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

struct GridOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for fraction in [CGFloat(1.0 / 3.0), CGFloat(2.0 / 3.0)] {
            path.move(to: CGPoint(x: rect.width * fraction, y: 0)); path.addLine(to: CGPoint(x: rect.width * fraction, y: rect.height))
            path.move(to: CGPoint(x: 0, y: rect.height * fraction)); path.addLine(to: CGPoint(x: rect.width, y: rect.height * fraction))
        }
        return path
    }
}
