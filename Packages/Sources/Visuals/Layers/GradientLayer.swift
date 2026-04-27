import SwiftUI
import CoreModels
import DesignSystem

public struct GradientLayer: View {

    /// How the rotated top-layer's opacity tracks `attitude.roll`.
    ///
    /// `.oneSidedAtRest` (default) — symmetric `|roll|` mapping: at roll = 0
    /// the rotated copy is invisible (only the bottom gradient shows), tilting
    /// in either direction raises the same swapped bitmap toward 100%. Use for
    /// surfaces where the resting visual should be a single, un-mixed gradient
    /// (e.g. the create-flow backdrop, the SaveButton-as-card-continuation).
    ///
    /// `.balancedAtRest` — signed `0.5 + 0.5 * roll` mapping: at roll = 0 the
    /// stack sits exactly 50/50, twisting positive drives the rotated copy to
    /// 100%, twisting negative drives the bottom copy to 100%. Use for
    /// surfaces where rest should already feel mixed and the direction of
    /// twist matters (e.g. the card stack — left twist and right twist read
    /// as different states, not just intensities).
    public enum Mode: Sendable {
        case oneSidedAtRest
        case balancedAtRest
    }

    public let timeOfDay: TimeOfDay
    public let attitude: DeviceAttitude
    public let mode: Mode
    /// Multiplies `attitude.roll` before the opacity curve is applied. `1.0`
    /// matches the global motion-pipeline full-scale (a full ±1 input fills
    /// the curve). Higher values amplify sensitivity for surfaces that should
    /// react to subtler tilts than a card backdrop — e.g. `2.0` reaches the
    /// curve's edge at half the physical rotation. The scaled roll is clamped
    /// to ±1 before the curve, so animations don't fly past their endpoints.
    public let gain: Double

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(
        timeOfDay: TimeOfDay,
        attitude: DeviceAttitude,
        mode: Mode = .oneSidedAtRest,
        gain: Double = 1.0
    ) {
        self.timeOfDay = timeOfDay
        self.attitude = attitude
        self.mode = mode
        self.gain = gain
    }

    public var body: some View {
        ZStack {
            Self.backdrop(for: timeOfDay)
            if !reduceTransparency {
                Self.backdrop(for: timeOfDay)
                    .rotationEffect(.degrees(180))
                    .opacity(Self.transfusionOpacity(
                        for: attitude,
                        mode: mode,
                        gain: gain,
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

    /// Top-layer opacity. Steps:
    /// 1. Multiply incoming `roll` by `gain` and clamp to ±1.
    /// 2. Apply the mode-specific curve:
    ///    - `.oneSidedAtRest`: `|scaled|` ∈ [0, 1] — rest is single-gradient.
    ///    - `.balancedAtRest`: `0.5 + 0.5 * scaled` ∈ [0, 1] — rest is 50/50,
    ///      sign of `scaled` selects which side dominates.
    /// Reduce Transparency forces 0 in either mode.
    static func transfusionOpacity(
        for attitude: DeviceAttitude,
        mode: Mode,
        gain: Double,
        reduceTransparency: Bool
    ) -> Double {
        guard !reduceTransparency else { return 0 }
        let scaled = max(-1, min(1, attitude.roll * gain))
        switch mode {
        case .oneSidedAtRest:
            return max(0, min(1, abs(scaled)))
        case .balancedAtRest:
            return max(0, min(1, 0.5 + 0.5 * scaled))
        }
    }

    /// Legacy three-arg variant — defaults `gain` to 1.0.
    static func transfusionOpacity(
        for attitude: DeviceAttitude,
        mode: Mode,
        reduceTransparency: Bool
    ) -> Double {
        transfusionOpacity(for: attitude, mode: mode, gain: 1.0, reduceTransparency: reduceTransparency)
    }

    /// Legacy two-arg variant — defaults to `.oneSidedAtRest`, gain 1.0.
    static func transfusionOpacity(
        for attitude: DeviceAttitude,
        reduceTransparency: Bool
    ) -> Double {
        transfusionOpacity(for: attitude, mode: .oneSidedAtRest, gain: 1.0, reduceTransparency: reduceTransparency)
    }

    /// Legacy single-argument variant, retained for existing callers/snapshot tests.
    static func transfusionOpacity(for attitude: DeviceAttitude) -> Double {
        transfusionOpacity(for: attitude, mode: .oneSidedAtRest, gain: 1.0, reduceTransparency: false)
    }
}
