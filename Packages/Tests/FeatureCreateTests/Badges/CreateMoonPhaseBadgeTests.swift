import Testing
import SwiftUI
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct CreateMoonPhaseBadgeTests {

    @Test func instantiatesForAllPhases() {
        for phase in MoonPhase.allCases {
            _ = CreateMoonPhaseBadge(phase: phase).body
        }
    }

    @Test func assetNamePreservesSourceTypo() {
        #expect(CreateMoonPhaseBadge.assetName(for: .waxingCrescent) == "Waxing_Crescennt")
        #expect(CreateMoonPhaseBadge.assetName(for: .waningCrescent) == "Waning_Crescennt")
        #expect(CreateMoonPhaseBadge.assetName(for: .newMoon) == "New_Moon")
        #expect(CreateMoonPhaseBadge.assetName(for: .firstQuarter) == "First_Quarter")
        #expect(CreateMoonPhaseBadge.assetName(for: .fullMoon) == "Full_Moon")
        #expect(CreateMoonPhaseBadge.assetName(for: .waxingGibbous) == "Waxing_Gibbous")
        #expect(CreateMoonPhaseBadge.assetName(for: .waningGibbous) == "Waning_Gibbous")
        #expect(CreateMoonPhaseBadge.assetName(for: .thirdQuarter) == "Third_Quarter")
    }
}
