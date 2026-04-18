import Testing
import Foundation
import CoreModels
@testable import Services

@Suite struct CoreMotionSmoothingTests {

    @Test func smoothedValueStartsFromFirstSample() {
        let smoother = AttitudeLowPass(alpha: 0.1)
        let out = smoother.smooth(DeviceAttitude(pitch: 1.0, roll: -1.0))
        #expect(out.pitch == 1.0)
        #expect(out.roll == -1.0)
    }

    @Test func smoothedValueTrailsRawSamples() {
        let smoother = AttitudeLowPass(alpha: 0.1)
        _ = smoother.smooth(DeviceAttitude(pitch: 0, roll: 0))
        let out = smoother.smooth(DeviceAttitude(pitch: 1.0, roll: 1.0))
        #expect(out.pitch > 0.0 && out.pitch < 1.0)
        #expect(out.roll > 0.0 && out.roll < 1.0)
    }

    @Test func smoothedValueClampsToRange() {
        let smoother = AttitudeLowPass(alpha: 0.5)
        let out = smoother.smooth(DeviceAttitude(pitch: 10.0, roll: -10.0))
        #expect(out.pitch == 1.0)
        #expect(out.roll == -1.0)
    }

    @Test func repeatedSamplesConvergeToTarget() {
        let smoother = AttitudeLowPass(alpha: 0.3)
        _ = smoother.smooth(.zero)
        var last = DeviceAttitude.zero
        for _ in 0..<100 {
            last = smoother.smooth(DeviceAttitude(pitch: 0.8, roll: 0.8))
        }
        #expect(abs(last.pitch - 0.8) < 0.001)
        #expect(abs(last.roll - 0.8) < 0.001)
    }
}
