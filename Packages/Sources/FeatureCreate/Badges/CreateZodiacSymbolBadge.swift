import SwiftUI
import CoreModels
import Visuals

/// Holographic zodiac figure for the create flow. 35×32 total: a
/// `Moon_Background` hologram frame with a 22×22 zodiac figure centered
/// inside. Matches the create-flow composition where the moon and zodiac
/// symbol share the same frame chrome.
struct CreateZodiacSymbolBadge: View {
    let sign: ZodiacSign
    let attitude: DeviceAttitude

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Image("Moon_Background", bundle: CCVisuals.bundle)
            .resizable()
            .scaledToFill()
            .frame(width: 35, height: 32)
            .clipped()
            .overlay(alignment: .center) {
                figureImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .offset(Self.translation(for: attitude))
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var figureImage: some View {
        let image = Image(Self.assetName(for: sign), bundle: CCVisuals.bundle)
        if reduceTransparency {
            image
        } else {
            image.renderingMode(.original)
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
