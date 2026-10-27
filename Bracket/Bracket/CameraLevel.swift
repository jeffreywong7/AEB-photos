import SwiftUI
import CoreMotion

private final class CameraLevelSensor: ObservableObject {
    private let motion = CMMotionManager()
    private let feedback = UISelectionFeedbackGenerator()
    private var alignmentFeedbackSent = false
    @Published private(set) var reading: CameraLevelReading?

    func start() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] value, _ in
            guard let self, let gravity = value?.gravity else { return }
            let next = CameraLevelReading(gravityX: gravity.x, gravityY: gravity.y, gravityZ: gravity.z)
            if let next {
                if next.isLevel && !self.alignmentFeedbackSent {
                    if self.reading != nil { self.feedback.selectionChanged() }
                    self.alignmentFeedbackSent = true
                } else if abs(next.angle) > .pi / 90 {
                    self.alignmentFeedbackSent = false
                }
            } else { self.alignmentFeedbackSent = false }
            self.reading = next
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        reading = nil
        alignmentFeedbackSent = false
    }

    deinit { motion.stopDeviceMotionUpdates() }
}

struct CameraLevelOverlay: View {
    let enabled: Bool
    let preview: Bool
    @StateObject private var sensor = CameraLevelSensor()
    @Environment(\.scenePhase) private var scenePhase

    private var reading: CameraLevelReading? {
        preview ? CameraLevelReading(gravityX: 0.025, gravityY: -0.99, gravityZ: 0) : sensor.reading
    }

    var body: some View {
        ZStack {
            if enabled, let reading {
                let color = reading.isLevel ? Color(uiColor: .systemYellow) : .white.opacity(0.85)
                ZStack {
                    HStack {
                        Rectangle().frame(width: 22, height: 1)
                        Spacer()
                        Rectangle().frame(width: 22, height: 1)
                    }
                    Rectangle().frame(width: 128, height: 1)
                        .rotationEffect(.radians(reading.angle))
                }
                .foregroundStyle(color)
                .frame(width: 180, height: 48)
                .accessibilityLabel(reading.isLevel ? "Camera level" : "Camera tilted")
                .accessibilityValue(String(format: "%.1f degrees", abs(reading.angle) * 180 / .pi))
            }
        }
        .allowsHitTesting(false)
        .onAppear { updateSensor() }
        .onChange(of: enabled) { _ in updateSensor() }
        .onChange(of: scenePhase) { _ in updateSensor() }
        .onDisappear { sensor.stop() }
    }

    private func updateSensor() {
        if enabled && !preview && scenePhase == .active { sensor.start() }
        else { sensor.stop() }
    }
}
