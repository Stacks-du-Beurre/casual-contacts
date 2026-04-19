import SwiftUI
import CoreModels

/// Animated holographic title per PDF §5 "Title/Name":
/// two stacked hologram bitmap layers whose chromatic transfusion tracks the
/// device's gyroscope, masked to letter-forms by a two-layer black text stack.
///
/// Stack (bottom → top), clipped to the pill's text-sized bounds:
///   1. *(optional, `showsBackdropBlur`)* Blurred duplicate of the scene behind
///      the pill (Figma `BACKGROUND_BLUR`). Default `true` to preserve existing
///      card-view behavior; the empty-state CTA opts out because the PDF §5
///      BERNARD sample shows no frosted base and on a bright pastel scene the
///      blur washes the `.lighten` hologram toward white.
///   2. Holographic texture, `.lighten` blend — translates on (x,y) with `attitude`.
///      Replaces the flat 56% white fill the Figma node stores (Figma is wrong
///      per the designer's PDF — two hologram bitmap fills, not a white fill).
///   3. Holographic texture, `.luminosity` blend @ 35% — rotates with `attitude`.
///   4. Text, black fill, `.overlay` blend.
///   5. Text, 20% black fill, normal blend.
///
/// The two hologram layers use the same source image; sliding/rotating one
/// against the other produces the chromatic transfusion the spec calls out
/// ("BERNARD" sample on PDF p.8). The text stack on top is a grayscale mask
/// that carves letter shapes out of that moving color field.
///
/// Used on the empty-state "add the first person" button and on populated
/// card names. Callers always pass real `attitude` — use `.zero` for static
/// previews / snapshot baselines.
public struct HologramText<Backdrop: View>: View {

    public let text: String
    public let font: Font
    public let attitude: DeviceAttitude
    public let hologram: HologramTexture
    public let showsBackdropBlur: Bool
    public let blurRadius: CGFloat
    public let lightenOpacity: Double
    public let luminosityOpacity: Double
    public let backdropSize: CGSize
    public let coordinateSpaceName: String
    private let backdrop: Backdrop

    /// Defaults below are tuneable. Bottom (`.lighten`) translates on roll/pitch,
    /// top (`.luminosity`) rotates on roll. Overscan keeps the textures covering
    /// the pill at full tilt / full rotation.
    public static var translationScaleX: CGFloat { 12 }
    public static var translationScaleY: CGFloat { 8 }
    public static var rotationDegrees: Double { 6 }
    public static var textureOverscan: CGFloat { 1.3 }

    public init(
        _ text: String,
        font: Font,
        attitude: DeviceAttitude,
        hologram: HologramTexture = .neon3,
        showsBackdropBlur: Bool = true,
        blurRadius: CGFloat = 54.365,
        lightenOpacity: Double = 0.56,
        luminosityOpacity: Double = 0.35,
        backdropSize: CGSize,
        coordinateSpaceName: String,
        @ViewBuilder backdrop: () -> Backdrop
    ) {
        self.text = text
        self.font = font
        self.attitude = attitude
        self.hologram = hologram
        self.showsBackdropBlur = showsBackdropBlur
        self.blurRadius = blurRadius
        self.lightenOpacity = lightenOpacity
        self.luminosityOpacity = luminosityOpacity
        self.backdropSize = backdropSize
        self.coordinateSpaceName = coordinateSpaceName
        self.backdrop = backdrop()
    }

    public var body: some View {
        textStack
            .padding(.horizontal, 6)
            .background(alignment: .topLeading) { chromaticStack }
    }

    private var textStack: some View {
        ZStack {
            Text(text)
                .font(font)
                .foregroundStyle(.black)
                .blendMode(.overlay)

            Text(text)
                .font(font)
                .foregroundStyle(Color.black.opacity(0.2))
        }
    }

    private var chromaticStack: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named(coordinateSpaceName))
            let overscanW = geo.size.width * Self.textureOverscan
            let overscanH = geo.size.height * Self.textureOverscan

            ZStack {
                if showsBackdropBlur {
                    backdrop
                        .frame(width: backdropSize.width, height: backdropSize.height)
                        .offset(x: -frame.minX, y: -frame.minY)
                        .blur(radius: blurRadius)
                }

                Image(hologram.rawValue, bundle: .module)
                    .resizable()
                    .scaledToFill()
                    .frame(width: overscanW, height: overscanH)
                    .offset(
                        x: CGFloat(attitude.roll) * Self.translationScaleX,
                        y: CGFloat(attitude.pitch) * Self.translationScaleY
                    )
                    .opacity(lightenOpacity)
                    .blendMode(.lighten)
                    .allowsHitTesting(false)

                Image(hologram.rawValue, bundle: .module)
                    .resizable()
                    .scaledToFill()
                    .frame(width: overscanW, height: overscanH)
                    .rotationEffect(.degrees(attitude.roll * Self.rotationDegrees))
                    .opacity(luminosityOpacity)
                    .blendMode(.luminosity)
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .accessibilityHidden(true)
        }
    }
}
