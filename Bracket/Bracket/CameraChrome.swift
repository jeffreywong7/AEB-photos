import SwiftUI
import AVKit

extension View {
    @ViewBuilder
    func cameraHardwareShutter(enabled: Bool, action: @escaping () -> Void) -> some View {
        if #available(iOS 18, *) {
            onCameraCaptureEvent(isEnabled: enabled) { event in
                if event.phase == .ended { action() }
            }
        } else { self }
    }

    @ViewBuilder
    func cameraGlass<S: Shape>(in shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            glassEffect(.regular.interactive(), in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.15), lineWidth: 0.5))
        }
        #else
        background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(.white.opacity(0.15), lineWidth: 0.5))
        #endif
    }

    @ViewBuilder
    func cameraGlassGroup() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 24) { self }
        } else { self }
        #else
        self
        #endif
    }
}
