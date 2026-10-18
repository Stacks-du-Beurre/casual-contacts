import SwiftUI
import CoreModels
import DesignSystem

public struct GuillocheBlendLayer: View, Animatable {

    public let paths: [Path]
    public let density: CCVisuals.Guilloche.LineDensity
    public let attitude: DeviceAttitude
    public let tint: Color
    public let depthScale: CGFloat
    public let reversed: Bool
    public let reverseDepthOrder: Bool
    public let reverseMotionDirection: Bool
    public let movementScaleX: Double
    public let movementScaleY: Double
    public let perspectiveAmount: Double
    public let skewAmount: Double
    public let microprintImage: CGImage?
    public let microprintMinimumSide: CGFloat
    public let microprintOpacity: Double
    public var reveal: Double

    /// `Animatable` hook — SwiftUI interpolates `reveal` per frame so each
    /// stacked path's opacity is re-computed at the animation framerate.
    nonisolated public var animatableData: Double {
        get { reveal }
        set { reveal = newValue }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.windowSceneProjection) private var windowScene
    @Environment(\.windowCardFrame) private var cardFrame
    @Environment(\.windowCardSize) private var cardSize
    @Environment(\.liveWindowGeometry) private var liveGeometry
    @Environment(\.usesProjectedGuillocheCanvas) private var useProjectedCanvas

    /// Default depth-scaling — how many points the Nth path offsets per unit of
    /// roll/pitch at the maximum depth. Empty-state hero uses a larger value for
    /// a pronounced deep-dive; list-card density stays subtler.
    nonisolated public static let defaultDepthScale: CGFloat = 0.5
    nonisolated public static let defaultMaxDepthLayer: Int = 15

    nonisolated private static let perspectiveCameraDistance: CGFloat = 2.0
    nonisolated private static let perspectiveMaxZ: CGFloat = 1.0

    public init(
        paths: [Path],
        density: CCVisuals.Guilloche.LineDensity,
        attitude: DeviceAttitude,
        tint: Color = CCDesign.Colors.L4,
        depthScale: CGFloat = GuillocheBlendLayer.defaultDepthScale,
        reversed: Bool = false,
        reverseDepthOrder: Bool = false,
        reverseMotionDirection: Bool = false,
        movementScaleX: Double = 1.0,
        movementScaleY: Double = 1.0,
        perspectiveAmount: Double = 1.0,
        skewAmount: Double = 0.08,
        microprintImage: CGImage? = nil,
        microprintMinimumSide: CGFloat = 0,
        microprintOpacity: Double = 1,
        reveal: Double = 1.0
    ) {
        self.paths = paths
        self.density = density
        self.attitude = attitude
        self.tint = tint
        self.depthScale = depthScale
        self.reversed = reversed
        self.reverseDepthOrder = reverseDepthOrder
        self.reverseMotionDirection = reverseMotionDirection
        self.movementScaleX = movementScaleX
        self.movementScaleY = movementScaleY
        self.perspectiveAmount = perspectiveAmount
        self.skewAmount = skewAmount
        self.microprintImage = microprintImage
        self.microprintMinimumSide = microprintMinimumSide
        self.microprintOpacity = microprintOpacity
        self.reveal = reveal
    }

    public var body: some View {
        #if os(iOS)
        let _ = PerformanceDiagnostics.shared.receivedViewBody(.blendStack)
        #endif
        Group {
            if let scene = windowScene, useProjectedCanvas && !CardRenderProbe.layeredGuilloche {
                projectedCanvas(scene)
            } else {
                layeredPaths
            }
        }
        .accessibilityHidden(true)
    }

    private var layeredPaths: some View {
        ZStack {
            ForEach(paths.indices, id: \.self) { index in
                let path = paths[index]
                let maxLayer = max(paths.count - 1, 0)
                let layer = reversed ? index : max(maxLayer - index, 0)
                let skew = Self.depthSkewTransform(
                    layer: layer,
                    attitude: attitude,
                    maxLayer: maxLayer,
                    reverseDepthOrder: reverseDepthOrder,
                    reverseMotionDirection: reverseMotionDirection,
                    perspectiveAmount: perspectiveAmount,
                    skewAmount: skewAmount
                )
                let transformedPath = windowScene == nil
                    ? path.applying(Self.centeredSkewTransform(bounds: path.boundingRect, skew: skew)) : path

                transformedPath
                    .stroke(tint.opacity(0.8 * localReveal(forIndex: index)), lineWidth: 0.5)
                    .offset(windowScene == nil ? Self.offset(
                        forPathIndex: index,
                        pathCount: paths.count,
                        attitude: attitude,
                        depthScale: depthScale,
                        reversed: reversed,
                        reverseDepthOrder: reverseDepthOrder,
                        reverseMotionDirection: reverseMotionDirection,
                        movementScaleX: movementScaleX,
                        movementScaleY: movementScaleY,
                        perspectiveAmount: perspectiveAmount
                    ) : .zero)
                    .windowDepth(CardSceneDepth.blendFraction(
                        index: index, count: paths.count,
                        reversed: windowScene?.reverseGuillocheDepthOrder == true
                    ))
            }
        }
    }

    private func projectedCanvas(_ scene: WindowSceneProjection) -> some View {
        GeometryReader { geometry in
            let local = geometry.frame(in: .named("CardScene"))
            let resolvedFrame = liveGeometry
                ? WindowSceneProjection.cardFrame(local: local, global: geometry.frame(in: .global), size: cardSize)
                : cardFrame
            let center = resolvedFrame.map { CGRect(x: $0.minX + local.minX, y: $0.minY + local.minY, width: local.width, height: local.height) }
                ?? geometry.frame(in: .global)
            // Paths can project outside the 184 × 160 artwork frame. Keep
            // the whole card available so Canvas does not crop that motion.
            let canvasSize = CGSize(width: max(cardSize.width, geometry.size.width),
                                    height: max(cardSize.height, geometry.size.height))
            let inset = CGSize(width: (canvasSize.width - geometry.size.width) / 2,
                               height: (canvasSize.height - geometry.size.height) / 2)
            let metersPerPoint = scene.screenWidthMeters / max(Double(scene.viewport.width), 1)
            let x = Double(center.midX - scene.viewport.width / 2) * metersPerPoint
            let y = -Double(center.midY - scene.viewport.height / 2) * metersPerPoint
            let reference = scene.reference(for: resolvedFrame ?? center)
            Canvas { context, _ in
                for index in paths.indices {
                    let fraction = CardSceneDepth.blendFraction(index: index, count: paths.count, reversed: scene.reverseGuillocheDepthOrder)
                    let depth = scene.backingDepthMeters * pow(max(0, min(1, fraction)), scene.spacing)
                    let projection = WindowPlaneProjection(eye: scene.eye, reference: reference, depth: depth)
                    let scale = projection?.scale ?? 1
                    let dx = ((scale - 1) * x + (projection?.translationX ?? 0)) / metersPerPoint
                    let dy = -((scale - 1) * y + (projection?.translationY ?? 0)) / metersPerPoint
                    var layer = context
                    layer.translateBy(x: canvasSize.width / 2 + dx, y: canvasSize.height / 2 + dy)
                    layer.scaleBy(x: scale, y: scale)
                    layer.translateBy(x: -geometry.size.width / 2, y: -geometry.size.height / 2)
                    layer.stroke(paths[index], with: .color(tint.opacity(0.8 * localReveal(forIndex: index))), lineWidth: 0.5)
                }
                if let microprintImage, reveal >= 1 {
                    // Use the same plane as the nearest actual guilloche layer.
                    let fraction = CardMicroprintLayer.depthFraction(pathCount: paths.count,
                        reversed: scene.reverseGuillocheDepthOrder)
                    let depth = scene.backingDepthMeters * pow(fraction, scene.spacing)
                    let projection = WindowPlaneProjection(eye: scene.eye, reference: reference, depth: depth)
                    let scale = projection?.scale ?? 1
                    let dx = ((scale - 1) * x + (projection?.translationX ?? 0)) / metersPerPoint
                    let dy = -((scale - 1) * y + (projection?.translationY ?? 0)) / metersPerPoint
                    let side = max(226, microprintMinimumSide)
                    var printContext = context
                    printContext.opacity = microprintOpacity
                    printContext.translateBy(x: canvasSize.width / 2 + dx, y: canvasSize.height / 2 + dy)
                    printContext.scaleBy(x: scale, y: scale)
                    var ink = printContext.resolve(Image(decorative: microprintImage, scale: 3))
                    ink.shading = .color(tint)
                    printContext.draw(ink, in: CGRect(x: -side / 2, y: -side / 2, width: side, height: side))
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .offset(x: -inset.width, y: -inset.height)
        }
    }

    /// Per-path reveal opacity. Under Reduce Motion every path shares the
    /// global `reveal` so the layer simply cross-fades. Otherwise paths are
    /// revealed inner→outer and strictly sequentially — each path occupies
    /// its own 1/`total` slice of the reveal window, and only starts after
    /// the previous one has finished (no overlap).
    private func localReveal(forIndex index: Int) -> Double {
        guard reveal > 0 else { return 0 }
        if reduceMotion { return reveal }

        let total = max(paths.count, 1)
        let orderedIndex = reversed ? index : (total - 1 - index)
        let slot = 1.0 / Double(total)
        let start = Double(orderedIndex) * slot
        let local = (reveal - start) / slot
        return min(max(local, 0), 1)
    }

    nonisolated static func offset(
        forPathIndex index: Int,
        pathCount: Int = 0,
        attitude: DeviceAttitude,
        depthScale: CGFloat = GuillocheBlendLayer.defaultDepthScale,
        reversed: Bool = false,
        reverseDepthOrder: Bool = false,
        reverseMotionDirection: Bool = false,
        movementScaleX: Double = 1.0,
        movementScaleY: Double = 1.0,
        perspectiveAmount: Double = 1.0
    ) -> CGSize {
        // The anchored end of the stack stays put; the opposite end swims by
        // the perspective-projected maximum depth. Translation follows the
        // same roll/pitch direction as the card's frosted location-pill blur
        // so every motion-reactive x/y layer reads as one coherent movement.
        //   reversed=false: last path is anchored, first path swims most.
        //   reversed=true:  first path is anchored, last path swims most.
        let maxLayer = max(pathCount - 1, 0)
        let step = reversed ? index : max(maxLayer - index, 0)
        let depth = perspectiveDepth(
            layer: step,
            maxLayer: maxLayer,
            depthScale: depthScale,
            reverseDepthOrder: reverseDepthOrder,
            perspectiveAmount: perspectiveAmount
        )
        let direction: CGFloat = reverseMotionDirection ? -1 : 1
        return CGSize(
            width: direction * CGFloat(attitude.roll) * depth * CGFloat(movementScaleX),
            height: direction * CGFloat(attitude.pitch) * depth * CGFloat(movementScaleY)
        )
    }

    /// Translation that a sibling layer would receive if it were the Nth path
    /// in the blend stack. Apply via `.offset(...)` on any view that should
    /// read as "deeper" or "shallower" than the blend stack — moon phase,
    /// zodiac glyph, constellation, etc.
    ///
    /// Layer 0 is anchored (no translation); higher layers use a perspective
    /// projection so foreground layers separate faster than background layers.
    /// Negative input is clamped to zero.
    nonisolated public static func depthOffset(
        layer: Int,
        attitude: DeviceAttitude,
        depthScale: CGFloat = GuillocheBlendLayer.defaultDepthScale,
        maxLayer: Int = GuillocheBlendLayer.defaultMaxDepthLayer,
        reverseDepthOrder: Bool = false,
        reverseMotionDirection: Bool = false,
        movementScaleX: Double = 1.0,
        movementScaleY: Double = 1.0,
        perspectiveAmount: Double = 1.0
    ) -> CGSize {
        let depth = perspectiveDepth(
            layer: layer,
            maxLayer: maxLayer,
            depthScale: depthScale,
            reverseDepthOrder: reverseDepthOrder,
            perspectiveAmount: perspectiveAmount
        )
        let direction: CGFloat = reverseMotionDirection ? -1 : 1
        return CGSize(
            width: direction * CGFloat(attitude.roll) * depth * CGFloat(movementScaleX),
            height: direction * CGFloat(attitude.pitch) * depth * CGFloat(movementScaleY)
        )
    }

    nonisolated public static func depthSkewTransform(
        layer: Int,
        attitude: DeviceAttitude,
        maxLayer: Int = GuillocheBlendLayer.defaultMaxDepthLayer,
        reverseDepthOrder: Bool = false,
        reverseMotionDirection: Bool = false,
        perspectiveAmount: Double = 1.0,
        skewAmount: Double = 0.08
    ) -> CGAffineTransform {
        let normalized = perspectiveDepthFraction(
            layer: layer,
            maxLayer: maxLayer,
            reverseDepthOrder: reverseDepthOrder,
            perspectiveAmount: perspectiveAmount
        )
        guard normalized > 0, skewAmount > 0 else { return .identity }

        let direction: CGFloat = reverseMotionDirection ? -1 : 1
        let pitchSkew = direction * CGFloat(attitude.pitch) * normalized * CGFloat(skewAmount)
        let rollSkew = direction * CGFloat(attitude.roll) * normalized * CGFloat(skewAmount)
        guard pitchSkew != 0 || rollSkew != 0 else { return .identity }

        return CGAffineTransform(a: 1, b: pitchSkew, c: rollSkew, d: 1, tx: 0, ty: 0)
    }

    nonisolated public static func centeredSkewTransform(
        bounds: CGRect,
        skew: CGAffineTransform
    ) -> CGAffineTransform {
        guard !bounds.isNull, !bounds.isEmpty, skew != .identity else { return skew }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        return CGAffineTransform(translationX: -center.x, y: -center.y)
            .concatenating(skew)
            .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
    }

    /// Translation applied to the most-shifted path in the stack — the path
    /// opposite the anchored end. Apply this to a sibling layer (e.g. the
    /// rotation guilloche) so it drifts in lockstep with the blend's swimming
    /// stroke instead of sitting still while the blend slides past it.
    nonisolated public static func maxDepthOffset(
        pathCount: Int,
        attitude: DeviceAttitude,
        depthScale: CGFloat = GuillocheBlendLayer.defaultDepthScale,
        reverseDepthOrder: Bool = false,
        reverseMotionDirection: Bool = false,
        movementScaleX: Double = 1.0,
        movementScaleY: Double = 1.0,
        perspectiveAmount: Double = 1.0
    ) -> CGSize {
        let maxLayer = max(pathCount - 1, 0)
        return depthOffset(
            layer: reverseDepthOrder ? 0 : maxLayer,
            attitude: attitude,
            depthScale: depthScale,
            maxLayer: maxLayer,
            reverseDepthOrder: reverseDepthOrder,
            reverseMotionDirection: reverseMotionDirection,
            movementScaleX: movementScaleX,
            movementScaleY: movementScaleY,
            perspectiveAmount: perspectiveAmount
        )
    }

    nonisolated private static func perspectiveDepth(
        layer: Int,
        maxLayer: Int,
        depthScale: CGFloat,
        reverseDepthOrder: Bool,
        perspectiveAmount: Double
    ) -> CGFloat {
        let normalized = perspectiveDepthFraction(
            layer: layer,
            maxLayer: maxLayer,
            reverseDepthOrder: reverseDepthOrder,
            perspectiveAmount: perspectiveAmount
        )
        return normalized * CGFloat(maxLayer) * depthScale
    }

    nonisolated private static func perspectiveDepthFraction(
        layer: Int,
        maxLayer: Int,
        reverseDepthOrder: Bool,
        perspectiveAmount: Double
    ) -> CGFloat {
        guard maxLayer > 0 else { return 0 }

        let clampedLayer = min(max(layer, 0), maxLayer)
        let effectiveLayer = reverseDepthOrder ? maxLayer - clampedLayer : clampedLayer
        guard effectiveLayer > 0 else { return 0 }

        let t = CGFloat(effectiveLayer) / CGFloat(maxLayer)
        let z = t * perspectiveMaxZ
        let projected = z / max(perspectiveCameraDistance - z, .leastNonzeroMagnitude)
        let maxProjected = perspectiveMaxZ / (perspectiveCameraDistance - perspectiveMaxZ)
        let perspectiveNormalized = projected / maxProjected
        let perspectiveDelta = perspectiveNormalized - t
        return max(0, t + perspectiveDelta * CGFloat(max(0, perspectiveAmount)))
    }
}

private struct ProjectedGuillocheCanvasKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// List-only renderer. Large canvases made fullscreen dismissal slower.
    var usesProjectedGuillocheCanvas: Bool {
        get { self[ProjectedGuillocheCanvasKey.self] }
        set { self[ProjectedGuillocheCanvasKey.self] = newValue }
    }
}
