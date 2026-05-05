import SwiftUI
import CoreModels
import Visuals

/// Right-edge constellation stars for the create flow. 100×90, decorative-only.
/// Shares the `{sign}_constellation` asset with the card's `ZodiacLayer` but
/// does not reuse that view because the create flow's composition and sizing
/// are different.
struct CreateConstellationBadge: View {
    let sign: ZodiacSign
    let attitude: DeviceAttitude

    var body: some View {
        Image(Self.assetName(for: sign), bundle: CCVisuals.bundle)
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 90)
            .accessibilityHidden(true)
    }

    /// Match the existing ZodiacLayer asset-name convention:
    /// `sign.rawValue + "_constellation"`.
    private static func assetName(for sign: ZodiacSign) -> String {
        "\(sign.rawValue)_constellation"
    }

}
