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
    public let perspectiveAmount: Double
    public let skewAmount: Double
    public var reveal: Double

    /// `Animatable` hook — SwiftUI interpolates `reveal` per frame so each
    /// stacked path's opacity is re-computed at the animation framerate.
    nonisolated public var animatableData: Double {
        get { reveal }
        set { reveal = newValue }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        perspectiveAmount: Double = 1.0,
        skewAmount: Double = 0.08,
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
        self.perspectiveAmount = perspectiveAmount
        self.skewAmount = skewAmount
        self.reveal = reveal
    }

    public var body: some View {
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
                let transformedPath = path.applying(Self.centeredSkewTransform(bounds: path.boundingRect, skew: skew))

                transformedPath
                    .stroke(tint.opacity(0.8 * localReveal(forIndex: index)), lineWidth: 0.5)
                    .offset(Self.offset(
                        forPathIndex: index,
                        pathCount: paths.count,
                        attitude: attitude,
                        depthScale: depthScale,
                        reversed: reversed,
                        reverseDepthOrder: reverseDepthOrder,
                        reverseMotionDirection: reverseMotionDirection,
                        perspectiveAmount: perspectiveAmount
                    ))
            }
        }
        .accessibilityHidden(true)
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
            width: direction * CGFloat(attitude.roll) * depth,
            height: direction * CGFloat(attitude.pitch) * depth
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
            width: direction * CGFloat(attitude.roll) * depth,
            height: direction * CGFloat(attitude.pitch) * depth
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
