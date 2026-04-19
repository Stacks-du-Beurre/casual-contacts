import SwiftUI
import CoreModels
import Visuals

/// Moon phase with the hologram-frame backdrop visible. 35×56 total: a 34×56
/// `Moon_Background` frame with a 20×20 phase glyph pinned to the top center
/// (7pt top inset). Matches the Figma create-flow composition, where the moon
/// frame is fully visible (unlike the card where the bottom of the frame is
/// often clipped).
struct CreateMoonPhaseBadge: View {
    let phase: MoonPhase

    var body: some View {
        Image("Moon_Background", bundle: CCVisuals.bundle)
            .resizable()
            .scaledToFill()
            .frame(width: 35, height: 32)
            .clipped()
            .overlay(alignment: .center) {
                Image(Self.assetName(for: phase), bundle: CCVisuals.bundle)
                    .resizable()
                    .frame(width: 20, height: 20)
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
