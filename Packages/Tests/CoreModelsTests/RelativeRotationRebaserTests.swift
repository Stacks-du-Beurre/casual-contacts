import Foundation
import Testing
@testable import CoreModels

@Suite struct RelativeRotationRebaserTests {
    @Test func resetBaselineMakesNextSampleTheZeroPoint() {
        let rebaser = RelativeRotationRebaser()
        let start = Date()
        let baseline = Self.quaternion(axis: .x, angle: 0)
        let tilted = Self.quaternion(axis: .x, angle: 0.4)

        rebaser.process(quaternion: baseline, now: start)
        rebaser.process(quaternion: tilted, now: start.addingTimeInterval(0.1))
        #expect(abs(rebaser.relativePitch) > 0.1)

        rebaser.resetBaseline()
        rebaser.process(quaternion: tilted, now: start.addingTimeInterval(0.2))

        #expect(abs(rebaser.relativePitch) < 0.000_001)
        #expect(abs(rebaser.relativeTwist) < 0.000_001)
        #expect(!rebaser.isRebaseInProgress)
        #expect(rebaser.rebaseProgress == 0)
    }

    @Test func smallMovementStillCountsTowardSettleDuration() {
        let rebaser = RelativeRotationRebaser(
            settleDuration: MotionTuning.Defaults.zeroPointSettleDuration,
            movementThresholdRadians: MotionTuning.Defaults.zeroPointMovementThresholdRadians
        )
        let start = Date()
        let baseline = Self.quaternion(axis: .x, angle: 0)
        let tinyTilt = Self.quaternion(
            axis: .x,
            angle: MotionTuning.Defaults.zeroPointMovementThresholdRadians * 0.5
        )

        rebaser.process(quaternion: baseline, now: start)
        rebaser.process(quaternion: tinyTilt, now: start.addingTimeInterval(0.5))
        rebaser.process(
            quaternion: tinyTilt,
            now: start.addingTimeInterval(MotionTuning.Defaults.zeroPointSettleDuration + 0.1)
        )

        #expect(rebaser.isRebaseInProgress)
    }

    @Test func movementBeyondThresholdResetsSettleCountdown() {
        let rebaser = RelativeRotationRebaser(
            settleDuration: MotionTuning.Defaults.zeroPointSettleDuration,
            movementThresholdRadians: MotionTuning.Defaults.zeroPointMovementThresholdRadians
        )
        let start = Date()
        let baseline = Self.quaternion(axis: .x, angle: 0)
        let activeTilt = Self.quaternion(
            axis: .x,
            angle: MotionTuning.Defaults.zeroPointMovementThresholdRadians * 1.25
        )

        rebaser.process(quaternion: baseline, now: start)
        rebaser.process(
            quaternion: activeTilt,
            now: start.addingTimeInterval(MotionTuning.Defaults.zeroPointSettleDuration - 0.1)
        )
        rebaser.process(
            quaternion: activeTilt,
            now: start.addingTimeInterval(MotionTuning.Defaults.zeroPointSettleDuration + 0.1)
        )

        #expect(!rebaser.isRebaseInProgress)
    }

    private enum Axis {
        case x
        case y
    }

    private static func quaternion(axis: Axis, angle: Double) -> SIMD4<Double> {
        let half = angle / 2
        let sine = sin(half)
        let cosine = cos(half)
        switch axis {
        case .x:
            return SIMD4(sine, 0, 0, cosine)
        case .y:
            return SIMD4(0, sine, 0, cosine)
        }
    }
}
