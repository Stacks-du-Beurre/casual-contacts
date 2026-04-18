import Testing
import Foundation
import CoreModels
@testable import AppFeature

@Suite struct ReducedMotionAdapterTests {

    @Test func rawAttitudePassesThroughWhenReduceMotionDisabled() {
        let raw = DeviceAttitude(pitch: 0.5, roll: -0.3)
        let out = ReducedMotionAdapter.attitude(raw: raw, reduceMotionEnabled: false)
        #expect(out == raw)
    }

    @Test func zeroAttitudeReturnedWhenReduceMotionEnabled() {
        let raw = DeviceAttitude(pitch: 0.5, roll: -0.3)
        let out = ReducedMotionAdapter.attitude(raw: raw, reduceMotionEnabled: true)
        #expect(out == .zero)
    }

    @Test func zeroStaysZero() {
        #expect(ReducedMotionAdapter.attitude(raw: .zero, reduceMotionEnabled: true) == .zero)
        #expect(ReducedMotionAdapter.attitude(raw: .zero, reduceMotionEnabled: false) == .zero)
    }
}
