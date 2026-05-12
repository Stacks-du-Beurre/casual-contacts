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

    @Test func reverseMotionDirectionDefaultsOnAndPersists() {
        let defaults = scratchDefaults()
        let first = CardBlendTuning(defaults: defaults)

        #expect(first.reverseMotionDirection == true)
        #expect(first.motionDirectionMultiplier == -1)

        first.reverseMotionDirection = false

        let second = CardBlendTuning(defaults: defaults)
        #expect(second.reverseMotionDirection == false)
        #expect(second.motionDirectionMultiplier == 1)
    }

    @Test func resetRestoresReverseMotionDirectionDefault() {
        let tuning = CardBlendTuning(defaults: scratchDefaults())
        tuning.reverseMotionDirection = false

        tuning.reset()

        #expect(tuning.reverseMotionDirection == true)
        #expect(tuning.motionDirectionMultiplier == -1)
    }

    @Test func rotationGuillocheModeDefaultsToRotateOnlyAndPersists() {
        let defaults = scratchDefaults()
        let first = CardBlendTuning(defaults: defaults)

        #expect(first.rotationGuillocheMovesInsteadOfRotates == false)

        first.rotationGuillocheMovesInsteadOfRotates = true

        let second = CardBlendTuning(defaults: defaults)
        #expect(second.rotationGuillocheMovesInsteadOfRotates == true)
    }

    @Test func resetRestoresRotationGuillocheModeDefault() {
        let tuning = CardBlendTuning(defaults: scratchDefaults())
        tuning.rotationGuillocheMovesInsteadOfRotates = true

        tuning.reset()

        #expect(tuning.rotationGuillocheMovesInsteadOfRotates == false)
    }

    @Test func guillocheMovementScalesDefaultToReducedMovementAndPersist() {
        let defaults = scratchDefaults()
        let first = CardBlendTuning(defaults: defaults)

        #expect(first.guillocheMovementScaleX == 0.8)
        #expect(first.guillocheMovementScaleY == 0.8)

        first.guillocheMovementScaleX = 0.5
        first.guillocheMovementScaleY = 2.0

        let second = CardBlendTuning(defaults: defaults)
        #expect(second.guillocheMovementScaleX == 0.5)
        #expect(second.guillocheMovementScaleY == 2.0)
    }

    @Test func resetRestoresGuillocheMovementScaleDefaults() {
        let tuning = CardBlendTuning(defaults: scratchDefaults())
        tuning.guillocheMovementScaleX = 0.5
        tuning.guillocheMovementScaleY = 2.0

        tuning.reset()

        #expect(tuning.guillocheMovementScaleX == 0.8)
        #expect(tuning.guillocheMovementScaleY == 0.8)
    }
}
