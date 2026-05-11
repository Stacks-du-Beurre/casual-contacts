import Testing
import Foundation
@testable import Visuals

@Suite @MainActor struct GuillocheRotationTuningTests {

    private func scratchDefaults(function: String = #function) -> UserDefaults {
        let suite = "GuillocheRotationTuningTests.\(function).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultOpacitiesMatchSpec() {
        let tuning = GuillocheRotationTuning(defaults: scratchDefaults())
        #expect(tuning.cardOpacity == GuillocheRotationTuning.Defaults.cardOpacity)
        #expect(tuning.cardPhotoOpacity == GuillocheRotationTuning.Defaults.cardPhotoOpacity)
        #expect(tuning.emptyStateOpacity == GuillocheRotationTuning.Defaults.emptyStateOpacity)
        #expect(GuillocheRotationTuning.Defaults.cardOpacity == 0.2)
        #expect(GuillocheRotationTuning.Defaults.cardPhotoOpacity == 0.23)
        #expect(GuillocheRotationTuning.Defaults.emptyStateOpacity == 0.3)
    }

    @Test func opacityWritesPersistAcrossInstances() {
        let defaults = scratchDefaults()
        let first = GuillocheRotationTuning(defaults: defaults)
        first.cardOpacity = 0.15
        first.cardPhotoOpacity = 0.25
        first.emptyStateOpacity = 0.35
        let second = GuillocheRotationTuning(defaults: defaults)
        #expect(second.cardOpacity == 0.15)
        #expect(second.cardPhotoOpacity == 0.25)
        #expect(second.emptyStateOpacity == 0.35)
    }

    @Test func resetRestoresOpacityDefaults() {
        let tuning = GuillocheRotationTuning(defaults: scratchDefaults())
        tuning.cardOpacity = 0.4
        tuning.cardPhotoOpacity = 0.1
        tuning.emptyStateOpacity = 0.0
        tuning.reset()
        #expect(tuning.cardOpacity == GuillocheRotationTuning.Defaults.cardOpacity)
        #expect(tuning.cardPhotoOpacity == GuillocheRotationTuning.Defaults.cardPhotoOpacity)
        #expect(tuning.emptyStateOpacity == GuillocheRotationTuning.Defaults.emptyStateOpacity)
    }
}
