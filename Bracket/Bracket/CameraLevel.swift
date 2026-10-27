import SwiftUI
import CoreMotion
import OSLog

private final class CameraLevelSensor: ObservableObject {
    private let motion = CMMotionManager()
    private let feedback = UISelectionFeedbackGenerator()
    private let logger = Logger(subsystem: "com.example.Bracket", category: "CameraLevel")
    private var alignmentFeedbackSent = false
    private var previousReading: CameraLevelReading?
    #if DEBUG
    private var previewStartedAt: TimeInterval?
    #endif

    func start(preview: Bool) {
        #if DEBUG
        if preview {
            if previewStartedAt == nil { previewStartedAt = ProcessInfo.processInfo.systemUptime }
            return
        }
        #endif
        guard motion.isDeviceMotionAvailable,
              CMMotionManager.availableAttitudeReferenceFrames().contains(.xArbitraryZVertical) else {
            logger.error("Device motion is unavailable for the camera level")
            return
        }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        logger.debug("Camera level motion sampling started")
    }

    func reading(preview: Bool) -> CameraLevelReading? {
        #if DEBUG
        if preview {
            guard let previewStartedAt else { return nil }
            let uptime = ProcessInfo.processInfo.systemUptime
            if ProcessInfo.processInfo.arguments.contains("--camera-ui-level-motion") {
                switch Int((uptime - previewStartedAt) / 2) % 4 {
                case 0: return CameraLevelReading(gravityX: 0.1, gravityY: -0.995, gravityZ: 0)
                case 1: return CameraLevelReading(gravityX: 0, gravityY: -1, gravityZ: 0)
                case 2: return CameraLevelReading(gravityX: -0.1, gravityY: -0.995, gravityZ: 0)
                default: return CameraLevelReading(gravityX: 0, gravityY: 0, gravityZ: -1)
                }
            }
            return CameraLevelReading(gravityX: 0.025, gravityY: -0.99, gravityZ: 0)
        }
        #endif
        guard motion.isDeviceMotionActive, let sample = motion.deviceMotion else { return nil }
        return CameraLevelReading(gravityX: sample.gravity.x, gravityY: sample.gravity.y, gravityZ: sample.gravity.z,
                                  sampleAge: ProcessInfo.processInfo.systemUptime - sample.timestamp)
    }

    func updateFeedback(for reading: CameraLevelReading?) {
        if let reading {
            if reading.isLevel && !alignmentFeedbackSent {
                if previousReading != nil { feedback.selectionChanged() }
                alignmentFeedbackSent = true
            } else if abs(reading.angle) > .pi / 90 {
                alignmentFeedbackSent = false
            }
        } else { alignmentFeedbackSent = false }
        previousReading = reading
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        #if DEBUG
        previewStartedAt = nil
        #endif
        previousReading = nil
        alignmentFeedbackSent = false
    }

    deinit { motion.stopDeviceMotionUpdates() }
}

struct CameraLevelOverlay: View {
    let enabled: Bool
    let preview: Bool
    @StateObject private var sensor = CameraLevelSensor()
    @Environment(\.scenePhase) private var scenePhase

    private var active: Bool { enabled && scenePhase == .active }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active)) { context in
            let reading = active ? sensor.reading(preview: preview) : nil
            ZStack {
                if let reading { indicator(reading) }
            }
            .frame(width: 180, height: 48)
            .onChange(of: context.date) { _ in sensor.updateFeedback(for: reading) }
        }
        .allowsHitTesting(false)
        .onAppear { updateSensor() }
        .onChange(of: enabled) { _ in updateSensor() }
        .onChange(of: scenePhase) { _ in updateSensor() }
        .onDisappear { sensor.stop() }
    }

    private func updateSensor() {
        if active { sensor.start(preview: preview) }
        else { sensor.stop() }
    }

    private func indicator(_ reading: CameraLevelReading) -> some View {
        let color = reading.isLevel ? Color(uiColor: .systemYellow) : .white.opacity(0.85)
        let degrees = reading.angle == 0 ? 0 : reading.angle * 180 / .pi
        return ZStack {
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
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("camera.level")
        .accessibilityLabel(reading.isLevel ? "Camera level" : "Camera tilted")
        .accessibilityValue(String(format: "%.1f degrees", degrees))
    }
}
