import CoreModels
import SwiftUI

public struct PhotoLayer: View {

    public let image: Image
    public let imageSize: CGSize?
    public let focus: NormalizedPoint?
    public let style: Style

    public enum Style: Sendable {
        case card
        case recommended  // Phase 3 — designed-in, still renders correctly
    }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(
        image: Image,
        imageSize: CGSize? = nil,
        focus: NormalizedPoint? = nil,
        style: Style = .card
    ) {
        self.image = image
        self.imageSize = imageSize
        self.focus = focus
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
                framedImage
            } else {
                framedImage
                    .blendMode(.luminosity)
                    .opacity(0.6)
            }
        case .recommended:
            if reduceTransparency {
                framedImage
                    .clipShape(Circle())
            } else {
                ZStack {
                    framedImage.blendMode(.luminosity)
                    framedImage.blendMode(.color)
                }
                .clipShape(Circle())
            }
        }
    }

    /// `scaledToFill` with an optional translation so the focus point lands at
    /// the container's geometric center, clamped to image bounds. Without a
    /// focus (or without the image's pixel size), behavior is byte-for-byte
    /// identical to the plain `.resizable().scaledToFill()` baseline.
    @ViewBuilder
    private var framedImage: some View {
        if let focus, let imageSize, imageSize.width > 0, imageSize.height > 0 {
            GeometryReader { geo in
                let offset = PhotoLayer.focusOffset(
                    container: geo.size,
                    imageSize: imageSize,
                    focus: focus
                )
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .offset(x: offset.width, y: offset.height)
                    .clipped()
            }
        } else {
            image
                .resizable()
                .scaledToFill()
        }
    }

    /// Computes the SwiftUI `.offset` needed to place `focus` at the center of
    /// `container` when the image is rendered with `scaledToFill`, clamped so
    /// we never reveal empty margin past the image edge.
    static func focusOffset(
        container: CGSize,
        imageSize: CGSize,
        focus: NormalizedPoint
    ) -> CGSize {
        guard container.width > 0, container.height > 0,
              imageSize.width > 0, imageSize.height > 0
        else { return .zero }

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = container.width / container.height

        // scaledToFill: cover the container; one axis overflows past its bounds.
        let scaledWidth: CGFloat
        let scaledHeight: CGFloat
        if imageAspect > containerAspect {
            scaledHeight = container.height
            scaledWidth = container.height * imageAspect
        } else {
            scaledWidth = container.width
            scaledHeight = container.width / imageAspect
        }

        let desiredDX = (0.5 - focus.x) * scaledWidth
        let desiredDY = (0.5 - focus.y) * scaledHeight

        let maxDX = max(0, (scaledWidth - container.width) / 2)
        let maxDY = max(0, (scaledHeight - container.height) / 2)

        return CGSize(
            width: min(max(desiredDX, -maxDX), maxDX),
            height: min(max(desiredDY, -maxDY), maxDY)
        )
    }
}
