import SwiftUI
import CoreModels
import DesignSystem

public struct GradientLayer: View {

    public let timeOfDay: TimeOfDay
    public let attitude: DeviceAttitude

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(timeOfDay: TimeOfDay, attitude: DeviceAttitude) {
        self.timeOfDay = timeOfDay
        self.attitude = attitude
    }

    public var body: some View {
        ZStack {
            Self.backdrop(for: timeOfDay)
            if !reduceTransparency {
                Self.backdrop(for: timeOfDay)
                    .rotationEffect(.degrees(180))
                    .opacity(Self.transfusionOpacity(
                        for: attitude,
                        reduceTransparency: false
                    ))
            }
        }
        .accessibilityHidden(true)
    }

    /// Resolves the canonical bitmap gradient for a given `TimeOfDay`.
    /// Mirrors `CCDesign.Gradients.view(for:)` but kept here for symmetry with
    /// the prior `gradient(for:)` API shape and to keep `body` readable.
    static func backdrop(for timeOfDay: TimeOfDay) -> CCDesign.GradientBackdrop {
        switch timeOfDay {
        case .dawn:     return CCDesign.Gradients.dawn
        case .sunrise:  return CCDesign.Gradients.sunrise
        case .midday:   return CCDesign.Gradients.midday
        case .sunset:   return CCDesign.Gradients.sunset
        case .dusk:     return CCDesign.Gradients.dusk
        case .night:    return CCDesign.Gradients.night
        case .midnight: return CCDesign.Gradients.midnight
        }
    }

    /// Top-layer opacity tracks `|attitude.roll|` ∈ [0, 1] → [0, 1].
    /// At roll = 0 (resting / Reduce Motion) opacity is 0 — only the bottom
    /// gradient is visible at 100%. Tilting in either direction brings the
    /// rotated top layer up (50/50 at |roll| = 0.5, full swap at |roll| = 1).
    /// Reduce Transparency forces 0.
    static func transfusionOpacity(
        for attitude: DeviceAttitude,
        reduceTransparency: Bool
    ) -> Double {
        guard !reduceTransparency else { return 0 }
        return max(0, min(1, abs(attitude.roll)))
    }

    /// Legacy single-argument variant, retained for existing callers/snapshot tests.
    static func transfusionOpacity(for attitude: DeviceAttitude) -> Double {
        transfusionOpacity(for: attitude, reduceTransparency: false)
    }
}
