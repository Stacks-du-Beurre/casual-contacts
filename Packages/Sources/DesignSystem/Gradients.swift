import SwiftUI
import CoreModels

public extension CCDesign {
    enum Gradients {

        // Bitmap-backed time-of-day gradients. Canonical source is the designer's
        // PNGs in `Resources/Gradients.xcassets/`, matching `docs/CC Design Specifications.pdf §2`.
        // See `GradientBackdrop` for the rendering primitive.

        public static var dawn:     GradientBackdrop { .init(assetName: "Dawn") }
        public static var sunrise:  GradientBackdrop { .init(assetName: "Sunrise") }
        public static var midday:   GradientBackdrop { .init(assetName: "Midday") }
        public static var sunset:   GradientBackdrop { .init(assetName: "Sunset") }
        public static var dusk:     GradientBackdrop { .init(assetName: "Dusk") }
        public static var night:    GradientBackdrop { .init(assetName: "Night") }
        public static var midnight: GradientBackdrop { .init(assetName: "Midnight") }

        public static var all: [GradientBackdrop] {
            [dawn, sunrise, midday, sunset, dusk, night, midnight]
        }

        /// Maps a `TimeOfDay` to the canonical bitmap gradient for that period.
        public static func view(for timeOfDay: TimeOfDay) -> GradientBackdrop {
            switch timeOfDay {
            case .dawn:     return dawn
            case .sunrise:  return sunrise
            case .midday:   return midday
            case .sunset:   return sunset
            case .dusk:     return dusk
            case .night:    return night
            case .midnight: return midnight
            }
        }
    }
}
