import SwiftUI
import CoreModels

public struct HolographicZodiac: View {

    public let sign: ZodiacSign
    public let attitude: DeviceAttitude

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(sign: ZodiacSign, attitude: DeviceAttitude) {
        self.sign = sign
        self.attitude = attitude
    }

    public var body: some View {
        if reduceTransparency {
            ZodiacLayer(sign: sign, attitude: .zero, variant: .figure)
                .accessibilityHidden(true)
        } else {
            ZodiacLayer(sign: sign, attitude: attitude, variant: .figure)
                .blendMode(.luminosity)
                .accessibilityHidden(true)
        }
    }
}
