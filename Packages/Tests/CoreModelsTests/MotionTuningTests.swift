import Foundation
import Testing
@testable import CoreModels

@Suite struct MotionTuningTests {
    @Test func zeroPointSettleDefaultsMatchSpec() {
        let tuning = MotionTuning(defaults: Self.scratchDefaults())

        #expect(tuning.zeroPointSettleDuration == 2.0)
        #expect(MotionTuning.Defaults.zeroPointSettleDurationMin == 0.5)
        #expect(MotionTuning.Defaults.zeroPointSettleDurationMax == 4.0)
        #expect(MotionTuning.Defaults.zeroPointMovementThresholdRadians == 0.08)
    }

    @Test func zeroPointSettleDurationPersistsAcrossInstances() {
        let defaults = Self.scratchDefaults()
        let first = MotionTuning(defaults: defaults)
        first.zeroPointSettleDuration = 3.25

        let second = MotionTuning(defaults: defaults)
        #expect(second.zeroPointSettleDuration == 3.25)
    }

    @Test func resetRestoresZeroPointSettleDefault() {
        let tuning = MotionTuning(defaults: Self.scratchDefaults())
        tuning.zeroPointSettleDuration = 3.5

        tuning.reset()

        #expect(tuning.zeroPointSettleDuration == MotionTuning.Defaults.zeroPointSettleDuration)
    }

    private static func scratchDefaults() -> UserDefaults {
        let suite = "MotionTuningTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
