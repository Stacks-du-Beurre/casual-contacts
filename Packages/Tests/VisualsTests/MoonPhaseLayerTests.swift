import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import Visuals

@Suite struct MoonPhaseLayerTests {

    @Test
    @MainActor
    func layerInstantiatesForEveryPhase() {
        for phase in MoonPhase.allCases {
            let layer = MoonPhaseLayer(phase: phase)
            _ = layer.body  // verify no crash during view construction
        }
    }

    @Test func assetNamesArePredictable() {
        #expect(MoonPhaseLayer.assetName(for: .newMoon) == "New_Moon")
        #expect(MoonPhaseLayer.assetName(for: .fullMoon) == "Full_Moon")
    }
}
