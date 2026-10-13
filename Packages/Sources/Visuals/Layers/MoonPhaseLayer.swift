import SwiftUI
import CoreModels

public struct MoonPhaseLayer: View {

    public let phase: MoonPhase
    public let sizeScale: CGFloat

    public init(phase: MoonPhase, sizeScale: CGFloat = 1) {
        self.phase = phase
        self.sizeScale = sizeScale
    }

    // Figma `Full_Moon` frame (`I17:41798;39:14177`): 34×56 horizontal-line
    // backdrop with a 20×20 phase glyph pinned to top, horizontally centered
    // (top inset 7 ≈ (34 − 20) / 2 horizontal inset as well).
    public var body: some View {
        Image("Moon_Background", bundle: .module)
            .resizable(resizingMode: .tile)
            .frame(width: 34 * sizeScale, height: 56 * sizeScale)
            .clipped()
            .overlay(alignment: .top) {
                Image(Self.assetName(for: phase), bundle: .module)
                    .resizable()
                    .frame(width: 20 * sizeScale, height: 20 * sizeScale)
                    .padding(.top, 7 * sizeScale)
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
