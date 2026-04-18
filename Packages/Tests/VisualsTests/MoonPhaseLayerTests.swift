import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import Visuals

@Suite struct MoonPhaseLayerTests {

    @Test func everyPhaseHasABundledAsset() {
        let bundle = Bundle.module
        for phase in MoonPhase.allCases {
            let name = MoonPhaseLayer.assetName(for: phase)
            let url = bundle.url(forResource: name, withExtension: "svg", subdirectory: "Moon")
                ?? bundle.url(forResource: name, withExtension: "svg")
            #expect(url != nil, "Missing moon asset: \(name)")
        }
    }

    @Test func assetNamesArePredictable() {
        #expect(MoonPhaseLayer.assetName(for: .newMoon) == "New_Moon")
        #expect(MoonPhaseLayer.assetName(for: .fullMoon) == "Full_Moon")
    }
}
