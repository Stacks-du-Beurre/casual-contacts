import SwiftUI
import CoreModels
import DesignSystem

public struct HolographicText: View {

    public let text: String
    public let attitude: DeviceAttitude
    public let font: Font

    public init(text: String, attitude: DeviceAttitude, font: Font = CCDesign.Typography.title) {
        self.text = text
        self.attitude = attitude
        self.font = font
    }

    public var body: some View {
        ZStack {
            Text(text)
                .font(font)
                .foregroundStyle(.white)
                .blendMode(.lighten)
                .offset(x: CGFloat(attitude.roll) * 8, y: CGFloat(attitude.pitch) * 8)
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            Text(text)
                .font(font)
                .foregroundStyle(.white)
                .blendMode(.luminosity)
                .rotationEffect(.degrees(attitude.roll * 3))
                .minimumScaleFactor(0.7)
                .lineLimit(2)
        }
    }
}
