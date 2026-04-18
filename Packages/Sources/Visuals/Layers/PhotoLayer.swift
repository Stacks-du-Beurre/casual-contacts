import SwiftUI

public struct PhotoLayer: View {

    public let image: Image
    public let style: Style

    public enum Style: Sendable {
        case card
        case recommended  // Phase 3 — designed-in, still renders correctly
    }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(image: Image, style: Style = .card) {
        self.image = image
        self.style = style
    }

    public var body: some View {
        content
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .card:
            if reduceTransparency {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                image
                    .resizable()
                    .scaledToFill()
                    .blendMode(.luminosity)
                    .opacity(0.6)
            }
        case .recommended:
            if reduceTransparency {
                image
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                ZStack {
                    image.resizable().scaledToFill().blendMode(.luminosity)
                    image.resizable().scaledToFill().blendMode(.color)
                }
                .clipShape(Circle())
            }
        }
    }
}
