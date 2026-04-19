import SwiftUI
import CoreModels
import Visuals

/// Holographic zodiac figure for the create flow. 35×32 total: a
/// `Moon_Background` hologram frame with a 22×22 chromatic-glyph centered
/// inside. Chromatic fill is a single neon texture, rotated by device roll,
/// masked by the zodiac figure shape — mirrors `HolographicZodiac` on the
/// card and tracks `ZodiacHologramTuning.shared`.
struct CreateZodiacSymbolBadge: View {
    let sign: ZodiacSign
    let attitude: DeviceAttitude

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Bindable private var tuning = ZodiacHologramTuning.shared

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
            Image(Self.assetName(for: sign), bundle: CCVisuals.bundle)
                .resizable()
                .scaledToFit()
        } else {
            chromaticFill
                .mask {
                    Image(Self.assetName(for: sign), bundle: CCVisuals.bundle)
                        .resizable()
                        .scaledToFit()
                }
        }
    }

    private var chromaticFill: some View {
        GeometryReader { geo in
            let overscanW = geo.size.width * Self.textureOverscan
            let overscanH = geo.size.height * Self.textureOverscan

            Image("Neon_3", bundle: CCVisuals.bundle)
                .resizable()
                .scaledToFill()
                .frame(width: overscanW, height: overscanH)
                .rotationEffect(.degrees(attitude.roll * tuning.rotationDegrees))
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .allowsHitTesting(false)
        }
    }

    /// Match the existing ZodiacLayer asset-name convention:
    /// `sign.rawValue + "_figure"`.
    private static func assetName(for sign: ZodiacSign) -> String {
        "\(sign.rawValue)_figure"
    }
}
