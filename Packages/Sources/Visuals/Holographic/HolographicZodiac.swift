import SwiftUI
import CoreModels

public struct HolographicZodiac: View {

    public let sign: ZodiacSign
    public let attitude: DeviceAttitude
    public let hologram: HologramTexture

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let tuning = ZodiacHologramTuning.shared

    private static let textureOverscan: CGFloat = 1.3

    public init(
        sign: ZodiacSign,
        attitude: DeviceAttitude,
        hologram: HologramTexture = .neon3
    ) {
        self.sign = sign
        self.attitude = attitude
        self.hologram = hologram
    }

    // The 35×32 figure frame reuses `Moon_Background` rendered at the moon
    // phase's native 34×56 and clipped to 35×32 — stripe density matches the
    // moon frame below. The chromatic hologram fill is masked by the zodiac
    // figure SVG so only the zodiac silhouette shows the shifting color
    // field; the stripe pattern sits on top. Tuning mirrors `HologramTuning`
    // but stores independent values — see `ZodiacHologramTuning`.
    public var body: some View {
        ZStack {
            chromaticFill
                .mask {
                    ZodiacLayer(
                        sign: sign,
                        attitude: reduceTransparency ? .zero : attitude,
                        variant: .figure
                    )
                    .frame(width: 22, height: 25)
                }

            Image("Moon_Background", bundle: .module)
                .resizable()
                .frame(width: 34, height: 56)
                .frame(width: 35, height: 32)
                .clipped()
        }
        .frame(width: 35, height: 32)
        .accessibilityHidden(true)
    }

    private var chromaticFill: some View {
        GeometryReader { geo in
            let overscanW = geo.size.width * Self.textureOverscan
            let overscanH = geo.size.height * Self.textureOverscan
            let roll = reduceTransparency ? 0 : attitude.roll

            Image(hologram.rawValue, bundle: .module)
                .resizable()
                .scaledToFill()
                .frame(width: overscanW, height: overscanH)
                .rotationEffect(.degrees(roll * tuning.rotationDegrees))
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .allowsHitTesting(false)
        }
    }
}
