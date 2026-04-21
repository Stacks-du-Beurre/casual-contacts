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
    @Bindable private var focusTuning = PhotoFocusTuning.shared

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

    /// Renders the image at `zoomMultiplier × scaledToFill` and shifts it so
    /// the focus point lands at the card's center (clamped to image bounds).
    /// `zoomMultiplier = 1.0` is the max zoom-out — scaledToFill, the photo
    /// fully covers the card. Multipliers above 1.0 zoom in on the face.
    /// Without image size, falls back to plain `.scaledToFill()`.
    @ViewBuilder
    private var framedImage: some View {
        if let focus, let imageSize, imageSize.width > 0, imageSize.height > 0 {
            GeometryReader { geo in
                let result = PhotoLayer.focusLayout(
                    container: geo.size,
                    imageSize: imageSize,
                    focus: focus,
                    zoomMultiplier: CGFloat(focusTuning.zoomMultiplier)
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
        zoomMultiplier: CGFloat
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

        // Never allow scale below fill — that would expose empty margin.
        let zoom = max(1.0, zoomMultiplier)
        let scaledWidth = fillWidth * zoom
        let scaledHeight = fillHeight * zoom

        let desiredDX = (0.5 - focus.x) * scaledWidth
        let desiredDY = (0.5 - focus.y) * scaledHeight

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
