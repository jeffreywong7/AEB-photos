#if DEBUG
import SwiftUI

// These fixtures exercise the real camera UI without requesting simulator camera access.
enum CameraInterfacePreview {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--camera-ui-preview") }
    static var state: String {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--camera-ui-state"), args.indices.contains(index + 1) else { return "photo" }
        return args[index + 1]
    }
}

struct CameraPreviewScene: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.24, green: 0.25, blue: 0.24)))
            var wall = Path()
            wall.move(to: .zero)
            wall.addLines([CGPoint(x: size.width * 0.64, y: size.height * 0.22),
                           CGPoint(x: size.width * 0.64, y: size.height * 0.68),
                           CGPoint(x: 0, y: size.height * 0.86)])
            wall.closeSubpath()
            context.fill(wall, with: .color(Color(red: 0.38, green: 0.39, blue: 0.35)))
            let window = CGRect(x: size.width * 0.16, y: size.height * 0.2, width: size.width * 0.26, height: size.height * 0.31)
            context.fill(Path(window), with: .color(Color(red: 0.64, green: 0.69, blue: 0.69)))
            context.stroke(Path(window), with: .color(.white.opacity(0.55)), lineWidth: 4)
        }
    }
}

struct CameraSnapshotWriter: UIViewRepresentable {
    func makeUIView(context: Context) -> SnapshotView { SnapshotView() }
    func updateUIView(_ view: SnapshotView, context: Context) {}

    final class SnapshotView: UIView {
        private var link: CADisplayLink?
        private var frames = 0

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil, link == nil, frames < 4 else { return }
            let link = CADisplayLink(target: self, selector: #selector(renderFrame))
            self.link = link
            link.add(to: .main, forMode: .common)
        }

        @objc private func renderFrame() {
            frames += 1
            guard frames == 4, let window else { return }
            link?.invalidate()
            link = nil
            DispatchQueue.main.async {
                window.layoutIfNeeded()
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                do {
                    try image.pngData()?.write(to: folder.appendingPathComponent("camera-\(CameraInterfacePreview.state).png"), options: .atomic)
                } catch { assertionFailure("Could not write camera UI snapshot: \(error)") }
            }
        }
    }
}
#endif

extension View {
    @ViewBuilder
    func cameraSnapshotPreview() -> some View {
        #if DEBUG
        if CameraInterfacePreview.enabled { background(CameraSnapshotWriter().frame(width: 0, height: 0)) }
        else { self }
        #else
        self
        #endif
    }
}
