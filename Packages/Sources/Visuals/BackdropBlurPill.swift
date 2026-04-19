import SwiftUI

/// Frosted chrome block: a blurred duplicate of the scene behind the view,
/// tinted by a fill color, sized to the content it wraps.
///
/// Matches the Figma `BACKGROUND_BLUR` primitive used on card chrome (e.g.
/// location pill). The caller passes the same scene twice — once painted
/// full-bleed and once into this view's `backdrop` builder — so this view
/// can re-render the backdrop at full scene size, offset it so the visible
/// region aligns with screen-space, and clip it to its own bounds. This
/// only works because the scene is deterministic; generic screens would
/// need a Metal-shader variant.
///
/// Extracted from the deprecated `HologramPill(hologramOpacity: 0, …)`
/// path when `HologramPill` was folded into `HologramText`. Use this
/// wherever you need the chrome without the luminosity hologram texture.
public struct BackdropBlurPill<Backdrop: View, Content: View>: View {

    public let fill: Color
    public let blurRadius: CGFloat
    public let backdropSize: CGSize
    public let coordinateSpaceName: String
    private let backdrop: Backdrop
    private let content: Content

    /// - Parameters:
    ///   - fill: Translucent color painted over the blurred backdrop to tint
    ///     the chrome. Typical values: `Color.white.opacity(0.56)` for a
    ///     frosted-white pill, `Color(r:40,g:60,b:85,opacity:0.1)` for the
    ///     cool-blue location pill.
    ///   - blurRadius: Background-blur radius. Default `54.365` — the stored
    ///     Figma `BACKGROUND_BLUR.radius` for card name chrome.
    ///   - backdropSize: Full size of the scene the chrome lives in.
    ///   - coordinateSpaceName: Named coordinate space on the outer scene
    ///     container; used to offset the duplicate backdrop into screen-space.
    ///   - backdrop: The same scene rendered behind this chrome (gradient +
    ///     guilloche, etc.).
    ///   - content: The chrome's foreground content.
    public init(
        fill: Color,
        blurRadius: CGFloat = 54.365,
        backdropSize: CGSize,
        coordinateSpaceName: String,
        @ViewBuilder backdrop: () -> Backdrop,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.blurRadius = blurRadius
        self.backdropSize = backdropSize
        self.coordinateSpaceName = coordinateSpaceName
        self.backdrop = backdrop()
        self.content = content()
    }

    public var body: some View {
        content
            .background(alignment: .topLeading) {
                GeometryReader { geo in
                    let frame = geo.frame(in: .named(coordinateSpaceName))
                    ZStack {
                        backdrop
                            .frame(width: backdropSize.width, height: backdropSize.height)
                            .offset(x: -frame.minX, y: -frame.minY)
                            .blur(radius: blurRadius)

                        fill
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .accessibilityHidden(true)
                }
            }
    }
}
