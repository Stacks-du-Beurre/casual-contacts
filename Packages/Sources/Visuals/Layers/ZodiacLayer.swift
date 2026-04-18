import SwiftUI
import CoreModels

public struct ZodiacLayer: View {

    public let sign: ZodiacSign
    public let attitude: DeviceAttitude
    public let variant: Variant

    public enum Variant: Sendable {
        case figure         // illustrated sign
        case constellation  // line-art constellation
    }

    public init(sign: ZodiacSign, attitude: DeviceAttitude, variant: Variant = .figure) {
        self.sign = sign
        self.attitude = attitude
        self.variant = variant
    }

    public var body: some View {
        Image(Self.assetName(for: sign, variant: variant), bundle: .module)
            .resizable()
            .scaledToFit()
            .offset(Self.translation(for: attitude))
    }

    static func assetName(for sign: ZodiacSign, variant: Variant) -> String {
        let suffix: String
        switch variant {
        case .figure: suffix = "_figure"
        case .constellation: suffix = "_constellation"
        }
        return sign.rawValue + suffix
    }

    /// Subtle parallax — 4pt max translation on tilt.
    static func translation(for attitude: DeviceAttitude) -> CGSize {
        CGSize(
            width: CGFloat(attitude.roll) * 4,
            height: CGFloat(attitude.pitch) * 4
        )
    }
}
