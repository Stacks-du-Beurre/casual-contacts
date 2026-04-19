import SwiftUI
import CoreModels
import Visuals

/// Holographic zodiac figure for the create flow. 35×32, decorative-only.
/// Loads the `{sign}_figure` asset directly from the shared Visuals bundle
/// and applies a luminosity blend mode for the "hologram" feel. Parallels
/// `HolographicZodiac` in Visuals but sized/positioned for this screen.
struct CreateZodiacSymbolBadge: View {
    let sign: ZodiacSign
    let attitude: DeviceAttitude

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let image = Image(Self.assetName(for: sign), bundle: CCVisuals.bundle)
            .resizable()
            .scaledToFit()
            .frame(width: 35, height: 32)
            .offset(Self.translation(for: attitude))
            .accessibilityHidden(true)

        if reduceTransparency {
            image
        } else {
            image.blendMode(.luminosity)
        }
    }

    /// Match the existing ZodiacLayer asset-name convention:
    /// `sign.rawValue + "_figure"`.
    private static func assetName(for sign: ZodiacSign) -> String {
        "\(sign.rawValue)_figure"
    }

    /// 4pt max parallax on tilt — matches the card's `ZodiacLayer` feel.
    private static func translation(for attitude: DeviceAttitude) -> CGSize {
        CGSize(
            width: CGFloat(attitude.roll) * 4,
            height: CGFloat(attitude.pitch) * 4
        )
    }
}
