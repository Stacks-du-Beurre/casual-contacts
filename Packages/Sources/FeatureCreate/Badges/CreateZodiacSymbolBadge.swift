import SwiftUI
import CoreModels
import Visuals

/// Holographic zodiac figure for the create flow. 35×32 total: a horizontal-
/// bar hologram frame with a 22×22 chromatic-glyph centered inside. Chromatic
/// fill is a single neon texture, rotated by device roll, masked by the
/// zodiac figure shape — mirrors `HolographicZodiac` on the card and tracks
/// `ZodiacHologramTuning.shared`.
///
/// `backgroundAssetName` defaults to the dark-mode `Moon_Background` tile.
/// The zodiac picker popover overrides this with `Moon_Background_Light`
/// when — and only when — the presenting view observes a light system
/// appearance; the caller resolves that condition and passes the asset name
/// explicitly (SwiftUI's `colorScheme` environment is forced dark inside
/// popover content, so the decision must be made by the presenter).
struct CreateZodiacSymbolBadge: View {
    let sign: ZodiacSign
    let attitude: DeviceAttitude
    var backgroundAssetName: String = "Moon_Background"

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Bindable private var tuning = ZodiacHologramTuning.shared

    private static let textureOverscan: CGFloat = 1.3

    var body: some View {
        Image(backgroundAssetName, bundle: CCVisuals.bundle)
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
