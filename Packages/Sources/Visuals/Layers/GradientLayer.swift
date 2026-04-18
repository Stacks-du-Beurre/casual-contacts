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
            Self.gradient(for: timeOfDay)
            if !reduceTransparency {
                Self.gradient(for: timeOfDay)
                    .opacity(Self.transfusionOpacity(for: attitude, reduceTransparency: false))
            }
        }
        .accessibilityHidden(true)
    }

    static func gradient(for timeOfDay: TimeOfDay) -> LinearGradient {
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

    /// Legacy single-argument variant, retained for existing callers/snapshot tests.
    static func transfusionOpacity(for attitude: DeviceAttitude) -> Double {
        (attitude.roll + 1) / 2
    }

    static func transfusionOpacity(for attitude: DeviceAttitude, reduceTransparency: Bool) -> Double {
        reduceTransparency ? 0 : (attitude.roll + 1) / 2
    }
}
