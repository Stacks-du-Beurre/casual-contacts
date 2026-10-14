import CoreModels
import DesignSystem
import SwiftUI

/// Atmospheric card backdrop — shared between `CardView` (list rows, detail)
/// and the create flow. Contains only the gradient + guilloche + photo-or-blend
/// layers. Does not render zodiac, moon, or text overlays.
public struct CardBackdrop: View {

    public let record: Record
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let photo: Image?
    public let photoSize: CGSize?
    public let showsGuilloche: Bool

    @Bindable private var blendTuning = CardBlendTuning.shared
    @Bindable private var elementDepthTuning = CardElementDepthTuning.shared
    @Environment(\.windowSceneProjection) private var windowScene
    @State private var reveal: Double = 0
    @State private var cachedSwirlPaths: [Path] = []
    /// Letter last used to seed the blend paths while the guilloche was
    /// visible. Held across the exit animation so deleting the final letter
    /// of the name fades the user's letter out — not the "A" fallback.
    @State private var persistedLetter: Character = "A"

    /// Reveal animation duration. Spans the full 72-step rotation sweep and
    /// the blend-path stack together, so the per-path slot is
    /// `revealDuration / path_count`.
    private static let revealDuration: Double = 0.4
    static let photoDepthLayer = 16

    public init(
        record: Record,
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        photo: Image? = nil,
        photoSize: CGSize? = nil,
        showsGuilloche: Bool = true
    ) {
        self.record = record
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
        self.photoSize = photoSize
        self.showsGuilloche = showsGuilloche
    }

    public var body: some View {
        let accoutrements = record.accoutrements
        let density: CCVisuals.Guilloche.LineDensity = .cards
        // While the guilloche is visible we use the live letter; during the
        // exit animation we freeze on the letter that was last shown so the
        // user sees "their" filigree fade out, not the default-A fallback.
        let renderLetter: Character = showsGuilloche ? accoutrements.letter : persistedLetter
        let blendPaths = paths.blendPaths(
            for: renderLetter,
            shape: accoutrements.guillocheShape,
            density: density
        )
        // In translate mode, match the rotation swirl's x/y movement to the
        // blend stack's most-shifted path. In rotate mode, keep it anchored so
        // it does not fight the attitude-driven rotation.
        let coupledOffset = GuillocheBlendLayer.maxDepthOffset(
            pathCount: blendPaths.count,
            attitude: attitude,
            depthScale: blendTuning.depthScale,
            reverseDepthOrder: blendTuning.reverseDepthOrder,
            reverseMotionDirection: blendTuning.reverseMotionDirection,
            movementScaleX: blendTuning.guillocheMovementScaleX,
            movementScaleY: blendTuning.guillocheMovementScaleY,
            perspectiveAmount: elementDepthTuning.perspectiveAmount
        )
        let movesRotationGuilloche = blendTuning.rotationGuillocheMovesInsteadOfRotates
        let rotationGuillocheAttitude: DeviceAttitude = (movesRotationGuilloche || windowScene != nil) ? .zero : attitude
        let rotationGuillocheOffset: CGSize = (movesRotationGuilloche && windowScene == nil) ? coupledOffset : .zero
        let photoParallaxOffset = Self.photoParallaxOffset(
            attitude: attitude,
            depthScale: blendTuning.depthScale,
            reverseDepthOrder: blendTuning.reverseDepthOrder,
            reverseMotionDirection: blendTuning.reverseMotionDirection,
            movementScaleX: blendTuning.guillocheMovementScaleX,
            movementScaleY: blendTuning.guillocheMovementScaleY,
            perspectiveAmount: elementDepthTuning.perspectiveAmount
        )
        let photoParallaxOverscan = Self.photoParallaxOverscan(
            depthScale: blendTuning.depthScale,
            reverseDepthOrder: blendTuning.reverseDepthOrder,
            reverseMotionDirection: blendTuning.reverseMotionDirection,
            movementScaleX: blendTuning.guillocheMovementScaleX,
            movementScaleY: blendTuning.guillocheMovementScaleY,
            perspectiveAmount: elementDepthTuning.perspectiveAmount
        )

        ZStack {
            if let windowScene {
                WindowGradientBackdrop(timeOfDay: record.metadata.timeOfDay, scene: windowScene)
            } else {
                GradientLayer(
                    timeOfDay: record.metadata.timeOfDay,
                    attitude: attitude,
                    mode: .balancedAtRest
                )
            }

            // Always mount both guilloche layers so the `reveal` driver can
            // animate per-path opacity into and out of view. At `reveal == 0`
            // each layer short-circuits stroking so the cost is negligible.
            GuillocheRotationLayer(
                paths: cachedSwirlPaths,
                tint: .white,
                attitude: rotationGuillocheAttitude,
                usage: Self.rotationGuillocheUsage(hasPhoto: photo != nil),
                reveal: reveal,
                minimumOpacity: Self.rotationOpacityFloor(for: record.metadata.timeOfDay)
            )
            .equatable()
            .offset(rotationGuillocheOffset)
            // Share the deepest blend plane exactly, including its scale and
            // global translation, rather than adding a separate swirl depth.
            .windowDepth(blendPaths.count > 1 ? CardSceneDepth.deepestBlendFraction : 0)

            if let photo {
                PhotoLayer(
                    image: photo,
                    photoID: record.photoID,
                    imageSize: photoSize,
                    focus: record.photoFocus,
                    parallaxOffset: windowScene == nil ? photoParallaxOffset : .zero,
                    parallaxOverscan: windowScene == nil ? photoParallaxOverscan : .zero,
                    style: .card
                )
            }

            GuillocheBlendLayer(
                paths: blendPaths,
                density: density,
                attitude: attitude,
                tint: .white,
                depthScale: blendTuning.depthScale,
                reversed: true,
                reverseDepthOrder: blendTuning.reverseDepthOrder,
                reverseMotionDirection: blendTuning.reverseMotionDirection,
                movementScaleX: blendTuning.guillocheMovementScaleX,
                movementScaleY: blendTuning.guillocheMovementScaleY,
                perspectiveAmount: elementDepthTuning.perspectiveAmount,
                skewAmount: elementDepthTuning.isSkewEnabled ? elementDepthTuning.skewAmount : 0,
                reveal: reveal
            )
            .frame(width: 184, height: 160)
            .opacity(Self.blendOpacity(for: record.metadata.timeOfDay))
        }
        .onAppear {
            // Snap to the current visibility on first render so stable views
            // (list rows, detail) don't replay the ink-in animation every
            // time they appear.
            persistedLetter = accoutrements.letter
            cachedSwirlPaths = GuillocheRotationLayer.swirlPaths(from: paths.rotationPaths(for: accoutrements.letter).first)
            reveal = showsGuilloche ? 1 : 0
        }
        .onChange(of: accoutrements.letter) { _, newLetter in
            // Only follow the live letter while we're currently showing —
            // during the exit animation the frozen letter keeps drawing.
            if showsGuilloche {
                persistedLetter = newLetter
                cachedSwirlPaths = GuillocheRotationLayer.swirlPaths(from: paths.rotationPaths(for: newLetter).first)
            }
        }
        .onChange(of: showsGuilloche) { _, shown in
            // Capture the latest letter on the way in so it's available as the
            // "frozen" letter during the next exit.
            if shown {
                persistedLetter = accoutrements.letter
                cachedSwirlPaths = GuillocheRotationLayer.swirlPaths(from: paths.rotationPaths(for: accoutrements.letter).first)
            }
            // The layers own the per-path stagger math; the animation here
            // simply interpolates `reveal` linearly across the full window.
            withAnimation(.linear(duration: Self.revealDuration)) {
                reveal = shown ? 1 : 0
            }
        }
    }

    // Raise contrast on bright gradients; retain the existing night opacities
    // and any user-selected rotation opacity above these measured floors.
    static func rotationOpacityFloor(for time: TimeOfDay) -> Double {
        switch time {
        case .dawn: 0.37
        case .sunrise: 0.42
        case .midday: 0.43
        case .sunset: 0.37
        case .dusk: 0.25
        case .night, .midnight: 0
        }
    }

    static func blendOpacity(for time: TimeOfDay) -> Double {
        switch time {
        case .dawn: 0.77
        case .sunrise: 0.87
        case .midday: 0.89
        case .sunset: 0.71
        case .dusk: 0.60
        case .night, .midnight: 0.55
        }
    }

    static func rotationGuillocheUsage(hasPhoto: Bool) -> GuillocheRotationLayer.Usage {
        hasPhoto ? .cardPhoto : .card
    }

    static func photoParallaxOffset(
        attitude: DeviceAttitude,
        depthScale: CGFloat,
        reverseDepthOrder: Bool,
        reverseMotionDirection: Bool,
        movementScaleX: Double,
        movementScaleY: Double,
        perspectiveAmount: Double
    ) -> CGSize {
        GuillocheBlendLayer.maxDepthOffset(
            pathCount: photoDepthLayer + 1,
            attitude: attitude,
            depthScale: depthScale,
            reverseDepthOrder: reverseDepthOrder,
            reverseMotionDirection: reverseMotionDirection,
            movementScaleX: movementScaleX,
            movementScaleY: movementScaleY,
            perspectiveAmount: perspectiveAmount
        )
    }

    static func photoParallaxOverscan(
        depthScale: CGFloat,
        reverseDepthOrder: Bool,
        reverseMotionDirection: Bool,
        movementScaleX: Double,
        movementScaleY: Double,
        perspectiveAmount: Double
    ) -> CGSize {
        let maxOffset = photoParallaxOffset(
            attitude: DeviceAttitude(pitch: 1, roll: 1),
            depthScale: depthScale,
            reverseDepthOrder: reverseDepthOrder,
            reverseMotionDirection: reverseMotionDirection,
            movementScaleX: movementScaleX,
            movementScaleY: movementScaleY,
            perspectiveAmount: perspectiveAmount
        )
        return CGSize(width: abs(maxOffset.width), height: abs(maxOffset.height))
    }
}
