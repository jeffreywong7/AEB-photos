import SwiftUI

extension View {
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
