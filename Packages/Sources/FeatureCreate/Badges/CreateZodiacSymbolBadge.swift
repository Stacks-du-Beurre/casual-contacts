import SwiftUI
import CoreModels
import Visuals

/// Holographic zodiac figure for the create flow. 35×32 total: a
/// `Moon_Background` hologram frame with a 22×22 chromatic-stack glyph
/// centered inside. The chromatic stack (two neon-texture layers blended
/// `.lighten` + `.luminosity` over a translucent white fill) is masked
/// by the zodiac figure shape and uses `HologramTuning.shared` so it
/// tracks the same calibration as the card's `HologramText` title.
struct CreateZodiacSymbolBadge: View {
    let sign: ZodiacSign
    let attitude: DeviceAttitude

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Bindable private var tuning = HologramTuning.shared

    private static let textureOverscan: CGFloat = 1.3

    var body: some View {
        Image("Moon_Background", bundle: CCVisuals.bundle)
            .resizable()
            .scaledToFill()
            .frame(width: 35, height: 32)
            .clipped()
            .overlay(alignment: .center) {
                chromaticGlyph
                    .frame(width: 22, height: 22)
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var chromaticGlyph: some View {
        if reduceTransparency {
            // Reduce Transparency: fall back to a solid silhouette.
            Image(Self.assetName(for: sign), bundle: CCVisuals.bundle)
                .resizable()
                .scaledToFit()
        } else {
            chromaticStack
                .mask {
                    Image(Self.assetName(for: sign), bundle: CCVisuals.bundle)
                        .resizable()
                        .scaledToFit()
                }
        }
    }

    private var chromaticStack: some View {
        GeometryReader { geo in
            let overscanW = geo.size.width * Self.textureOverscan
            let overscanH = geo.size.height * Self.textureOverscan

            ZStack {
                Color.white.opacity(tuning.whiteFillOpacity)

                Image("Neon_3", bundle: CCVisuals.bundle)
                    .resizable()
                    .scaledToFill()
                    .frame(width: overscanW, height: overscanH)
                    .offset(
                        x: CGFloat(attitude.roll) * CGFloat(tuning.translationScaleX),
                        y: CGFloat(attitude.pitch) * CGFloat(tuning.translationScaleY)
                    )
                    .opacity(tuning.lightenOpacity)
                    .blendMode(.lighten)

                Image("Neon_3", bundle: CCVisuals.bundle)
                    .resizable()
                    .scaledToFill()
                    .frame(width: overscanW, height: overscanH)
                    .rotationEffect(.degrees(attitude.roll * tuning.rotationDegrees))
                    .opacity(tuning.luminosityOpacity)
                    .blendMode(.luminosity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    /// Match the existing ZodiacLayer asset-name convention:
    /// `sign.rawValue + "_figure"`.
    private static func assetName(for sign: ZodiacSign) -> String {
        "\(sign.rawValue)_figure"
    }
}
