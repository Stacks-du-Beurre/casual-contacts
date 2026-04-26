import Testing
import Foundation
@testable import Visuals

@Suite @MainActor struct CardElementDepthTuningTests {

    private func scratchDefaults(function: String = #function) -> UserDefaults {
        let suite = "CardElementDepthTuningTests.\(function).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func defaultsMatchSpec() {
        let tuning = CardElementDepthTuning(defaults: scratchDefaults())
        #expect(tuning.moonPhaseLayer == 12)
        #expect(tuning.zodiacGlyphLayer == 4)
        #expect(tuning.zodiacConstellationLayer == 15)
        #expect(CardElementDepthTuning.layerRange == 0...15)
    }

    @Test func writesPersistAcrossInstances() {
        let defaults = scratchDefaults()
        let first = CardElementDepthTuning(defaults: defaults)
        first.moonPhaseLayer = 7
        first.zodiacGlyphLayer = 0
        first.zodiacConstellationLayer = 9
        let second = CardElementDepthTuning(defaults: defaults)
        #expect(second.moonPhaseLayer == 7)
        #expect(second.zodiacGlyphLayer == 0)
        #expect(second.zodiacConstellationLayer == 9)
    }

    @Test func resetRestoresDefaults() {
        let tuning = CardElementDepthTuning(defaults: scratchDefaults())
        tuning.moonPhaseLayer = 0
        tuning.zodiacGlyphLayer = 15
        tuning.zodiacConstellationLayer = 1
        tuning.reset()
        #expect(tuning.moonPhaseLayer == 12)
        #expect(tuning.zodiacGlyphLayer == 4)
        #expect(tuning.zodiacConstellationLayer == 15)
    }
}
