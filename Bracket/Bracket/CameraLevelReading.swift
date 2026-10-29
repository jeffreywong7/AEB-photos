import Foundation

struct CameraLevelReading: Equatable {
    let angle: Double
    var isLevel: Bool { abs(angle) <= .pi / 180 }

    init?(gravityX: Double, gravityY: Double, gravityZ: Double, sampleAge: TimeInterval = 0) {
        guard (0...0.5).contains(sampleAge), hypot(gravityX, gravityY) > 0.3, abs(gravityZ) < 0.9 else { return nil }
        let angle = atan2(-gravityX, -gravityY)
        guard abs(angle) <= .pi / 12 else { return nil }
        self.angle = angle
    }
}
