import Testing
import Foundation
@testable import Visuals

@Suite @MainActor struct EmptyStateGradientTuningTests {

    private func scratchDefaults(function: String = #function) -> UserDefaults {
        let suite = "EmptyStateGradientTuningTests.\(function).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultEdgeReachMatchesSpec() {
        let tuning = EmptyStateGradientTuning(defaults: scratchDefaults())
        #expect(tuning.edgeReach == EmptyStateGradientTuning.Defaults.edgeReach)
        #expect(EmptyStateGradientTuning.Defaults.edgeReach == 1.0)
    }

    @Test func writesPersistAcrossInstances() {
        let defaults = scratchDefaults()
        let first = EmptyStateGradientTuning(defaults: defaults)
        first.edgeReach = 0.42
        let second = EmptyStateGradientTuning(defaults: defaults)
        #expect(second.edgeReach == 0.42)
    }

    @Test func resetRestoresDefault() {
        let tuning = EmptyStateGradientTuning(defaults: scratchDefaults())
        tuning.edgeReach = 0.2
        tuning.reset()
        #expect(tuning.edgeReach == EmptyStateGradientTuning.Defaults.edgeReach)
    }
}
