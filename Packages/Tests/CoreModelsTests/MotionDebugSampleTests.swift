import Testing
import Foundation
@testable import CoreModels

@Suite struct MotionDebugSampleTests {

    private func makeSample(
        rawPitch: Double = 0.1,
        rawRoll: Double = 0.2,
        rawYaw: Double = 0.3,
        throttled: DeviceAttitude? = DeviceAttitude(pitch: 0.4, roll: 0.5)
    ) -> MotionDebugSample {
        MotionDebugSample(
            timestamp: Date(timeIntervalSince1970: 100),
            rawEulerPitch: rawPitch,
            rawEulerRoll: rawRoll,
            rawEulerYaw: rawYaw,
            rawQuaternion: SIMD4<Double>(0, 0, 0, 1),
            gravity: SIMD3<Double>(0, 0, -1),
            normalizedPitch: 0.06,
            normalizedRoll: 0.13,
            baseline: .zero,
            baselineRelative: DeviceAttitude(pitch: 0.06, roll: 0.13),
            smoothed: DeviceAttitude(pitch: 0.05, roll: 0.10),
            shaped: DeviceAttitude(pitch: 0.05, roll: 0.10),
            throttledOutput: throttled,
            secondsSinceSettleReset: 1.5,
            isRebaseInProgress: false,
            rebaseProgress: 0.0
        )
    }

    @Test func equalSamplesAreEqual() {
        let a = makeSample()
        let b = makeSample()
        #expect(a == b)
    }

    @Test func differingFieldsAreNotEqual() {
        let a = makeSample(rawPitch: 0.1)
        let b = makeSample(rawPitch: 0.2)
        #expect(a != b)
    }

    @Test func droppedFrameHasNilThrottledOutput() {
        let dropped = makeSample(throttled: nil)
        #expect(dropped.throttledOutput == nil)
    }

    @Test func sampleIsSendableAndHashable() {
        let a = makeSample()
        let set: Set<MotionDebugSample> = [a]
        #expect(set.contains(a))
    }
}
