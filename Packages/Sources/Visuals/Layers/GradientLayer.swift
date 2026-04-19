import SwiftUI
import CoreModels
import DesignSystem

public struct GradientLayer: View {

    public let timeOfDay: TimeOfDay
    public let attitude: DeviceAttitude

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Bindable private var tuning = GradientLayerTuning.shared

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
                        reduceTransparency: false,
                        sensitivity: tuning.motionSensitivity
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

    /// Spec §2 "Transfusion": top-layer opacity tracks `attitude.roll` ∈ [-1, 1] → [0, 1].
    /// At roll = 0 (resting / Reduce Motion) the result is 0.5 — the spec's "Default_50%" state.
    /// Reduce Transparency forces 0, collapsing to the bottom layer only.
    /// `sensitivity` scales roll before the [-1,1]→[0,1] mapping; > 1 flips the
    /// transfusion faster around roll = 0, `0` pins it at 50%. Result is clamped
    /// to [0, 1] so high sensitivity saturates rather than overshoots.
    static func transfusionOpacity(
        for attitude: DeviceAttitude,
        reduceTransparency: Bool,
        sensitivity: Double = 1.0
    ) -> Double {
        guard !reduceTransparency else { return 0 }
        let scaled = (attitude.roll * sensitivity + 1) / 2
        return max(0, min(1, scaled))
    }

    /// Legacy single-argument variant, retained for existing callers/snapshot tests.
    static func transfusionOpacity(for attitude: DeviceAttitude) -> Double {
        transfusionOpacity(for: attitude, reduceTransparency: false)
    }
}
