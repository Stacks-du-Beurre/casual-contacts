import SwiftUI
import CoreModels
import DesignSystem

public struct HolographicLocation: View {

    public let address: String
    public let attitude: DeviceAttitude

    public init(address: String, attitude: DeviceAttitude) {
        self.address = address
        self.attitude = attitude
    }

    public var body: some View {
        ZStack {
            Text(address)
                .font(CCDesign.Typography.caption1)
                .foregroundStyle(.white)
                .blendMode(.lighten)
                .blur(radius: 2)
                .offset(x: CGFloat(attitude.roll) * 8, y: CGFloat(attitude.pitch) * 8)

            Text(address)
                .font(CCDesign.Typography.caption1)
                .foregroundStyle(.white)
                .blendMode(.luminosity)
        }
    }
}
