import SwiftUI

public struct PhotoLayer: View {

    public let image: Image
    public let style: Style

    public enum Style: Sendable {
        case card
        case recommended  // Phase 3 — designed-in, still renders correctly
    }

    public init(image: Image, style: Style = .card) {
        self.image = image
        self.style = style
    }

    public var body: some View {
        switch style {
        case .card:
            image
                .resizable()
                .scaledToFill()
                .blendMode(.luminosity)
                .opacity(0.6)
        case .recommended:
            ZStack {
                image.resizable().scaledToFill().blendMode(.luminosity)
                image.resizable().scaledToFill().blendMode(.color)
            }
            .clipShape(Circle())
        }
    }
}
