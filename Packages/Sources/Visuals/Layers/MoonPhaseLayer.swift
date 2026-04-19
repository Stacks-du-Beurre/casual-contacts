import SwiftUI
import CoreModels

public struct MoonPhaseLayer: View {

    public let phase: MoonPhase

    public init(phase: MoonPhase) {
        self.phase = phase
    }

    // Figma `Full_Moon` frame (`I17:41798;39:14177`): 34×56 horizontal-line
    // backdrop with a 20×20 phase glyph pinned to top, horizontally centered
    // (top inset 7 ≈ (34 − 20) / 2 horizontal inset as well).
    public var body: some View {
        Image("Moon_Background", bundle: .module)
            .resizable()
            .frame(width: 34, height: 56)
            .clipped()
            .overlay(alignment: .top) {
                Image(Self.assetName(for: phase), bundle: .module)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .padding(.top, 7)
            }
            .accessibilityHidden(true)
    }

    static func assetName(for phase: MoonPhase) -> String {
        switch phase {
        case .newMoon:         return "New_Moon"
        case .waxingCrescent:  return "Waxing_Crescennt"  // preserve source typo
        case .firstQuarter:    return "First_Quarter"
        case .waxingGibbous:   return "Waxing_Gibbous"
        case .fullMoon:        return "Full_Moon"
        case .waningGibbous:   return "Waning_Gibbous"
        case .thirdQuarter:    return "Third_Quarter"
        case .waningCrescent:  return "Waning_Crescennt"  // preserve source typo
        }
    }
}
