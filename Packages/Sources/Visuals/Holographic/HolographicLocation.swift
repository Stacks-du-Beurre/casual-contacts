import SwiftUI
import CoreModels
import DesignSystem

public struct HolographicLocation: View {

    public let address: String
    public let attitude: DeviceAttitude

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(address: String, attitude: DeviceAttitude) {
        self.address = address
        self.attitude = attitude
    }

    public var body: some View {
        if reduceTransparency {
            Text(address)
                .font(CCDesign.Typography.caption1)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
        } else {
            ZStack {
                Text(address)
                    .font(CCDesign.Typography.caption1)
                    .foregroundStyle(.white)
                    .blendMode(.lighten)
                    .blur(radius: 2)
                    .offset(x: CGFloat(attitude.roll) * 8, y: CGFloat(attitude.pitch) * 8)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)

                Text(address)
                    .font(CCDesign.Typography.caption1)
                    .foregroundStyle(.white)
                    .blendMode(.luminosity)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
            }
        }
    }
}
