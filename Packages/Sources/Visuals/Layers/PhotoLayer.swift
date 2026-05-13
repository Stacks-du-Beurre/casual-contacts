import CoreModels
import SwiftUI

public struct PhotoLayer: View {

    public let image: Image
    public let imageSize: CGSize?
    public let focus: NormalizedPoint?
    public let parallaxOffset: CGSize
    public let parallaxOverscan: CGSize?
    public let style: Style

    public enum Style: Sendable {
        case card
        case recommended  // Phase 3 — designed-in, still renders correctly
    }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Bindable private var focusTuning = PhotoFocusTuning.shared

    public init(
        image: Image,
        imageSize: CGSize? = nil,
        focus: NormalizedPoint? = nil,
        parallaxOffset: CGSize = .zero,
        parallaxOverscan: CGSize? = nil,
        style: Style = .card
    ) {
        self.image = image
        self.imageSize = imageSize
        self.focus = focus
        self.parallaxOffset = parallaxOffset
        self.parallaxOverscan = parallaxOverscan
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
                    .opacity(focusTuning.opacity)
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

    /// Renders the image at `zoomMultiplier × scaledToFill`, with enough
    /// overscan for parallax movement, and shifts it so the focus point lands
    /// at the card's center (clamped to image bounds). Without image size,
    /// falls back to plain `.scaledToFill()`.
    @ViewBuilder
    private var framedImage: some View {
        if let imageSize, imageSize.width > 0, imageSize.height > 0 {
            GeometryReader { geo in
                let result = PhotoLayer.focusLayout(
                    container: geo.size,
                    imageSize: imageSize,
                    focus: focus ?? .center,
                    zoomMultiplier: CGFloat(focusTuning.zoomMultiplier),
                    parallaxOffset: parallaxOffset,
                    parallaxOverscan: parallaxOverscan
                )
                image
                    .resizable()
                    .frame(width: result.scaled.width, height: result.scaled.height)
                    .offset(x: result.offset.width, y: result.offset.height)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                    .clipped()
            }
        } else {
            image
                .resizable()
                .scaledToFill()
        }
    }

    /// Computes the scaled image dimensions and the SwiftUI `.offset` needed
    /// to center `focus` in `container` when the image is rendered at
    /// `zoomMultiplier × scaledToFill`. `zoomMultiplier` is clamped to be
    /// at least 1.0 — the image always covers the container. Offset is
    /// clamped so the image stays flush with the container bounds (no empty
    /// margin past the edge).
    static func focusLayout(
        container: CGSize,
        imageSize: CGSize,
        focus: NormalizedPoint,
        zoomMultiplier: CGFloat,
        parallaxOffset: CGSize = .zero,
        parallaxOverscan: CGSize? = nil
    ) -> (scaled: CGSize, offset: CGSize) {
        guard container.width > 0, container.height > 0,
              imageSize.width > 0, imageSize.height > 0
        else { return (container, .zero) }

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = container.width / container.height

        // scaledToFill base dims (cover the container exactly — one axis
        // overflows, the other matches the container).
        let fillWidth: CGFloat
        let fillHeight: CGFloat
        if imageAspect > containerAspect {
            fillHeight = container.height
            fillWidth = container.height * imageAspect
        } else {
            fillWidth = container.width
            fillHeight = container.width / imageAspect
        }

        // Never allow scale below fill, and reserve a stable parallax budget
        // so live attitude changes move the photo without resizing it.
        let overscan = parallaxOverscan ?? parallaxOffset
        let requiredWidth = container.width + 2 * abs(overscan.width)
        let requiredHeight = container.height + 2 * abs(overscan.height)
        let parallaxZoom = max(requiredWidth / fillWidth, requiredHeight / fillHeight)
        let zoom = max(1.0, zoomMultiplier, parallaxZoom)
        let scaledWidth = fillWidth * zoom
        let scaledHeight = fillHeight * zoom

        let desiredDX = (0.5 - focus.x) * scaledWidth + parallaxOffset.width
        let desiredDY = (0.5 - focus.y) * scaledHeight + parallaxOffset.height

        let maxDX = max(0, (scaledWidth - container.width) / 2)
        let maxDY = max(0, (scaledHeight - container.height) / 2)

        return (
            CGSize(width: scaledWidth, height: scaledHeight),
            CGSize(
                width: min(max(desiredDX, -maxDX), maxDX),
                height: min(max(desiredDY, -maxDY), maxDY)
            )
        )
    }
}
