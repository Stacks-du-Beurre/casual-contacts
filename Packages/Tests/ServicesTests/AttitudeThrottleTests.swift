import Testing
import Foundation
import CoreModels
@testable import Services

@Suite struct AttitudeThrottleTests {

    // MARK: - First-sample behavior

    @Test func firstSampleAlwaysEmits() {
        let throttle = AttitudeThrottle()
        let now = Date()
        let emitted = throttle.admit(DeviceAttitude(pitch: 0.1, roll: 0.2), now: now)
        #expect(emitted == DeviceAttitude(pitch: 0.1, roll: 0.2))
    }

    // MARK: - Base interval (moving)

    @Test func dropsSamplesFasterThanBaseIntervalWhenMoving() {
        let throttle = AttitudeThrottle(
            baseInterval: 1.0 / 30.0,
            idleInterval: 1.0 / 12.0,
            movementThreshold: 0.01
        )
        let start = Date()
        // Seed a first sample so subsequent calls are compared against it.
        _ = throttle.admit(DeviceAttitude(pitch: 0.0, roll: 0.0), now: start)
        // 1 / 60s later with a large delta — still under the 1/30 base interval.
        let emitted = throttle.admit(
            DeviceAttitude(pitch: 0.2, roll: 0.0),
            now: start.addingTimeInterval(1.0 / 60.0)
        )
        #expect(emitted == nil)
    }

    @Test func emitsAfterBaseIntervalElapsesWhenMoving() {
        let throttle = AttitudeThrottle(
            baseInterval: 1.0 / 30.0,
            idleInterval: 1.0 / 12.0,
            movementThreshold: 0.01
        )
        let start = Date()
        _ = throttle.admit(DeviceAttitude(pitch: 0.0, roll: 0.0), now: start)
        // Slightly past the base interval with a large delta → emit.
        let emitted = throttle.admit(
            DeviceAttitude(pitch: 0.2, roll: 0.0),
            now: start.addingTimeInterval(1.0 / 30.0 + 0.001)
        )
        #expect(emitted == DeviceAttitude(pitch: 0.2, roll: 0.0))
    }

    // MARK: - Idle interval (stationary)

    @Test func usesIdleIntervalWhenDeltaIsBelowThreshold() {
        let throttle = AttitudeThrottle(
            baseInterval: 1.0 / 30.0,
            idleInterval: 1.0 / 12.0,
            movementThreshold: 0.01
        )
        let start = Date()
        _ = throttle.admit(DeviceAttitude(pitch: 0.0, roll: 0.0), now: start)
        // 1/20s later (past base interval) but with tiny delta — should drop
        // because idle interval (1/12s) hasn't elapsed yet.
        let emitted = throttle.admit(
            DeviceAttitude(pitch: 0.005, roll: 0.005),
            now: start.addingTimeInterval(1.0 / 20.0)
        )
        #expect(emitted == nil)
    }

    @Test func emitsAfterIdleIntervalEvenWithSmallDelta() {
        let throttle = AttitudeThrottle(
            baseInterval: 1.0 / 30.0,
            idleInterval: 1.0 / 12.0,
            movementThreshold: 0.01
        )
        let start = Date()
        _ = throttle.admit(DeviceAttitude(pitch: 0.0, roll: 0.0), now: start)
        // Past the idle interval with a tiny delta — emit.
        let emitted = throttle.admit(
            DeviceAttitude(pitch: 0.005, roll: 0.005),
            now: start.addingTimeInterval(1.0 / 12.0 + 0.001)
        )
        #expect(emitted != nil)
    }

    // MARK: - Defaults

    @Test func defaultBaseIntervalMatchesCoreMotionRate() {
        // The throttle's base rate sits at the CoreMotion delegate's 60 Hz
        // ceiling so the gyro pipeline runs full rate when the user is moving
        // the device. Drop this if the per-card body cost ever regresses past
        // the GPU savings the per-card drawingGroup buys.
        let throttle = AttitudeThrottle()
        #expect(throttle.baseInterval == 1.0 / 60.0)
        #expect(throttle.idleInterval == 1.0 / 12.0)
    }

    // MARK: - Sustained rates

    @Test func sustainedMovementEmitsAtApproximatelyBaseRate() {
        let throttle = AttitudeThrottle(
            baseInterval: 1.0 / 30.0,
            idleInterval: 1.0 / 12.0,
            movementThreshold: 0.01
        )
        let start = Date()
        var emitted = 0
        // Feed 60 samples over 1 second with a 0.02 delta each — well above
        // threshold. Expect ~30 emissions (one per baseInterval).
        for i in 0..<60 {
            let t = start.addingTimeInterval(Double(i) / 60.0)
            let sample = DeviceAttitude(
                pitch: 0.02 * Double(i),
                roll: 0
            )
            if throttle.admit(sample, now: t) != nil { emitted += 1 }
        }
        #expect(emitted >= 28 && emitted <= 32, "expected ~30 emissions at base rate, got \(emitted)")
    }

    @Test func sustainedStationarySamplesEmitAtApproximatelyIdleRate() {
        let throttle = AttitudeThrottle(
            baseInterval: 1.0 / 30.0,
            idleInterval: 1.0 / 12.0,
            movementThreshold: 0.01
        )
        let start = Date()
        var emitted = 0
        // Feed 60 samples with zero delta — should fall to idle rate after the
        // first emission. Expect ~12 emissions over 1s (first + ~11 spaced
        // 1/12s apart).
        for i in 0..<60 {
            let t = start.addingTimeInterval(Double(i) / 60.0)
            if throttle.admit(.zero, now: t) != nil { emitted += 1 }
        }
        #expect(emitted >= 10 && emitted <= 13, "expected ~12 emissions at idle rate, got \(emitted)")
    }
}
