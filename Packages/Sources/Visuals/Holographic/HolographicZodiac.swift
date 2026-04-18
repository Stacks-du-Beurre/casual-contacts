import SwiftUI
import CoreModels

public struct HolographicZodiac: View {

    public let sign: ZodiacSign
    public let attitude: DeviceAttitude

    public init(sign: ZodiacSign, attitude: DeviceAttitude) {
        self.sign = sign
        self.attitude = attitude
    }

    public var body: some View {
        // Just translates — no rotation. Figurative asset already has holographic rendering baked in.
        ZodiacLayer(sign: sign, attitude: attitude, variant: .figure)
            .blendMode(.luminosity)
            .accessibilityHidden(true)
    }
}
