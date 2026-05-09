import Testing
import Foundation
@testable import Visuals

@Suite @MainActor struct CardBlendTuningTests {

    private func scratchDefaults(function: String = #function) -> UserDefaults {
        let suite = "CardBlendTuningTests.\(function).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func reverseDepthOrderDefaultsOffAndPersists() {
        let defaults = scratchDefaults()
        let first = CardBlendTuning(defaults: defaults)

        #expect(first.reverseDepthOrder == false)

        first.reverseDepthOrder = true

        let second = CardBlendTuning(defaults: defaults)
        #expect(second.reverseDepthOrder == true)
    }

    @Test func resetRestoresReverseDepthOrderDefault() {
        let tuning = CardBlendTuning(defaults: scratchDefaults())
        tuning.reverseDepthOrder = true

        tuning.reset()

        #expect(tuning.reverseDepthOrder == false)
    }

    @Test func reverseMotionDirectionDefaultsOffAndPersists() {
        let defaults = scratchDefaults()
        let first = CardBlendTuning(defaults: defaults)

        #expect(first.reverseMotionDirection == false)
        #expect(first.motionDirectionMultiplier == 1)

        first.reverseMotionDirection = true

        let second = CardBlendTuning(defaults: defaults)
        #expect(second.reverseMotionDirection == true)
        #expect(second.motionDirectionMultiplier == -1)
    }

    @Test func resetRestoresReverseMotionDirectionDefault() {
        let tuning = CardBlendTuning(defaults: scratchDefaults())
        tuning.reverseMotionDirection = true

        tuning.reset()

        #expect(tuning.reverseMotionDirection == false)
        #expect(tuning.motionDirectionMultiplier == 1)
    }
}
