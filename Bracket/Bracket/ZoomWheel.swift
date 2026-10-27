import SwiftUI

struct ZoomWheel: View {
    let zoom: CGFloat
    let limits: ClosedRange<CGFloat>
    let stops: [CGFloat]
    let mainFocalLength: Int?
    let onZoom: (CGFloat) -> Void
    let onClose: () -> Void

    private let yellow = Color(uiColor: .systemYellow)

    var body: some View {
        ZStack(alignment: .top) {
            Canvas { drawingContext, size in
                var context = drawingContext
                let radius = size.width * 0.6
                let center = CGPoint(x: size.width / 2, y: radius + 12)
                let circle = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: circle), with: .color(.black.opacity(0.45)))
                let first = Int(ceil(log2(Double(limits.lowerBound)) * 18))
                let last = Int(floor(log2(Double(limits.upperBound)) * 18))
                if first <= last {
                    for step in first...last {
                        let value = CGFloat(pow(2, Double(step) / 18))
                        tick(value, radius: radius, center: center, length: 13, context: &context)
                    }
                }
                for value in stops {
                    let angle = angle(for: value)
                    guard abs(angle) < .pi / 2 else { continue }
                    tick(value, radius: radius, center: center, length: 26, context: &context)
                    if abs(angle) > 0.06 {
                        var labelContext = context
                        labelContext.translateBy(x: center.x + CGFloat(sin(angle)) * (radius - 36), y: center.y - CGFloat(cos(angle)) * (radius - 36))
                        labelContext.rotate(by: .radians(angle))
                        labelContext.draw(Text(label(value)).font(.system(size: 14)).foregroundColor(.white), at: .zero)
                        if abs(value - 1) < 0.01, let mainFocalLength {
                            labelContext.draw(Text("\(mainFocalLength) MM").font(.system(size: 10)).foregroundColor(.white.opacity(0.5)), at: CGPoint(x: 0, y: 16))
                        }
                    }
                }
            }
            .accessibilityLabel("Zoom wheel")
            .accessibilityAction(named: "Close zoom wheel", onClose)
            .accessibilityValue("\(label(zoom)) times")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onZoom(min(zoom * 1.05, limits.upperBound))
                case .decrement: onZoom(max(zoom / 1.05, limits.lowerBound))
                @unknown default: break
                }
            }
            VStack(spacing: 14) {
                Image(systemName: "arrowtriangle.down.fill").font(.system(size: 8))
                Text("\(label(zoom))×").font(.system(size: 16, weight: .medium)).monospacedDigit()
            }
            .foregroundStyle(yellow)
            .padding(.top, 12)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

        }
        .clipped()
    }

    private func angle(for value: CGFloat) -> Double {
        log2(Double(value / zoom)) * .pi / 12
    }

    private func tick(_ value: CGFloat, radius: CGFloat, center: CGPoint, length: CGFloat, context: inout GraphicsContext) {
        let angle = angle(for: value)
        guard abs(angle) < .pi / 2 else { return }
        var path = Path()
        path.move(to: CGPoint(x: center.x + CGFloat(sin(angle)) * (radius - 5), y: center.y - CGFloat(cos(angle)) * (radius - 5)))
        path.addLine(to: CGPoint(x: center.x + CGFloat(sin(angle)) * (radius - 5 - length), y: center.y - CGFloat(cos(angle)) * (radius - 5 - length)))
        context.stroke(path, with: .color(.white.opacity(length > 13 ? 0.9 : 0.4)), lineWidth: 1)
    }

    private func label(_ value: CGFloat) -> String {
        String(format: abs(value - value.rounded()) < 0.01 ? "%.0f" : "%.1f", Double(value))
    }
}
