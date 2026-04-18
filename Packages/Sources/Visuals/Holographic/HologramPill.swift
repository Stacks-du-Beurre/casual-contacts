import SwiftUI

/// Frosted pill with a holographic fill, reproducing the Figma `name` layer stack
/// (e.g. empty-state "add the first person", populated card names).
///
/// Layer order bottom-to-top inside the pill's shape:
///   1. Blurred duplicate of the scene behind the pill (Figma `BACKGROUND_BLUR`).
///   2. Translucent white fill (Figma fill 1, `bg-[rgba(255,255,255,0.56)]`).
///   3. Holographic texture with `.luminosity` blend at 35% (Figma fill 2).
///   4. Caller-supplied content (the name text).
///
/// To reproduce the blurred backdrop without private APIs, the caller supplies the
/// same scene twice: once painted full-bleed and once passed as the pill's
/// `backdrop` builder. The pill re-renders the backdrop at the full scene size,
/// clipped to its own shape, and offsets it so the visible region aligns with
/// what would be behind the pill in screen space. This only works because the
/// scene is deterministic — generic screens (with arbitrary content behind)
/// would need a Metal-shader variant instead.
public struct HologramPill<Backdrop: View, Content: View>: View {

    public let hologram: HologramTexture
    public let whiteFill: Double
    public let blurRadius: CGFloat
    public let hologramOpacity: Double
    public let backdropSize: CGSize
    public let coordinateSpaceName: String
    private let backdrop: Backdrop
    private let content: Content

    /// - Parameters:
    ///   - hologram: Which holographic texture to use as fill 2. Default `.neon3`.
    ///   - whiteFill: Opacity of the translucent white fill 1. Default `0.56`.
    ///   - blurRadius: Background-blur radius applied to the duplicated backdrop.
    ///     Default `54.365` — the stored Figma `BACKGROUND_BLUR.radius` for the
    ///     empty-state `name` layer.
    ///   - hologramOpacity: Opacity of the luminosity-blended hologram fill.
    ///     Default `0.35` per Figma.
    ///   - backdropSize: The full size of the scene the pill lives in. The pill
    ///     renders its duplicate of `backdrop` at this size, so the portion
    ///     visible inside the pill's clip region matches what would be behind
    ///     it at screen space.
    ///   - coordinateSpaceName: Named coordinate space declared on the outer
    ///     scene container; used to measure the pill's position inside that
    ///     container for the duplicate-backdrop offset.
    ///   - backdrop: A builder that returns the same scene rendered behind the
    ///     pill (gradient + guilloche, etc.).
    ///   - content: The pill's foreground, typically a `HologramText` or a
    ///     styled `Text`.
    public init(
        hologram: HologramTexture = .neon3,
        whiteFill: Double = 0.56,
        blurRadius: CGFloat = 54.365,
        hologramOpacity: Double = 0.35,
        backdropSize: CGSize,
        coordinateSpaceName: String,
        @ViewBuilder backdrop: () -> Backdrop,
        @ViewBuilder content: () -> Content
    ) {
        self.hologram = hologram
        self.whiteFill = whiteFill
        self.blurRadius = blurRadius
        self.hologramOpacity = hologramOpacity
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

                        Color.white.opacity(whiteFill)

                        // Hologram texture sized to COVER the pill: preserves
                        // aspect ratio, scales up to fully fill the pill region,
                        // then crops the overflow.
                        Image(hologram.rawValue, bundle: .module)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .opacity(hologramOpacity)
                            .blendMode(.luminosity)
                            .allowsHitTesting(false)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .accessibilityHidden(true)
                }
            }
    }
}
