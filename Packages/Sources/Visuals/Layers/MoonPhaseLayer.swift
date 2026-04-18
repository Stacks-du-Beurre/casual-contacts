import SwiftUI
import CoreModels

public struct MoonPhaseLayer: View {

    public let phase: MoonPhase

    public init(phase: MoonPhase) {
        self.phase = phase
    }

    public var body: some View {
        Image(Self.assetName(for: phase), bundle: .module)
            .resizable()
            .scaledToFit()
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
