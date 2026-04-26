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
    public var reveal: Double

    /// `Animatable` hook — SwiftUI interpolates `reveal` per frame so each
    /// stacked path's opacity is re-computed at the animation framerate.
    nonisolated public var animatableData: Double {
        get { reveal }
        set { reveal = newValue }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Default depth-scaling — how many points the Nth path offsets per unit of
    /// roll/pitch. Empty-state hero uses a larger value for a pronounced
    /// deep-dive; list-card density stays subtle at 0.5.
    nonisolated public static let defaultDepthScale: CGFloat = 0.5

    public init(
        paths: [Path],
        density: CCVisuals.Guilloche.LineDensity,
        attitude: DeviceAttitude,
        tint: Color = CCDesign.Colors.L4,
        depthScale: CGFloat = GuillocheBlendLayer.defaultDepthScale,
        reversed: Bool = false,
        reveal: Double = 1.0
    ) {
        self.paths = paths
        self.density = density
        self.attitude = attitude
        self.tint = tint
        self.depthScale = depthScale
        self.reversed = reversed
        self.reveal = reveal
    }

    public var body: some View {
        ZStack {
            ForEach(paths.indices, id: \.self) { index in
                paths[index]
                    .stroke(tint.opacity(0.8 * localReveal(forIndex: index)), lineWidth: 0.5)
                    .offset(Self.offset(
                        forPathIndex: index,
                        pathCount: paths.count,
                        attitude: attitude,
                        depthScale: depthScale,
                        reversed: reversed
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
        reversed: Bool = false
    ) -> CGSize {
        // The anchored end of the stack stays put; the opposite end swims by
        // `(pathCount - 1) * depthScale`. Translation runs counter to the
        // tilt direction so the stack appears to swim away from the lift.
        //   reversed=false: last path is anchored, first path swims most.
        //   reversed=true:  first path is anchored, last path swims most.
        let step = reversed ? index : max(pathCount - 1 - index, 0)
        let depth = CGFloat(step) * depthScale
        return CGSize(
            width: -CGFloat(attitude.roll) * depth,
            height: -CGFloat(attitude.pitch) * depth
        )
    }

    /// Translation that a sibling layer would receive if it were the Nth path
    /// in the blend stack. Apply via `.offset(...)` on any view that should
    /// read as "deeper" or "shallower" than the blend stack — moon phase,
    /// zodiac glyph, constellation, etc.
    ///
    /// Layer 0 is anchored (no translation); layer N has translation
    /// `N × depthScale × attitude`. Negative input is clamped to zero.
    nonisolated public static func depthOffset(
        layer: Int,
        attitude: DeviceAttitude,
        depthScale: CGFloat = GuillocheBlendLayer.defaultDepthScale
    ) -> CGSize {
        let depth = CGFloat(max(layer, 0)) * depthScale
        return CGSize(
            width: -CGFloat(attitude.roll) * depth,
            height: -CGFloat(attitude.pitch) * depth
        )
    }

    /// Translation applied to the most-shifted path in the stack — the path
    /// opposite the anchored end. Apply this to a sibling layer (e.g. the
    /// rotation guilloche) so it drifts in lockstep with the blend's swimming
    /// stroke instead of sitting still while the blend slides past it.
    nonisolated public static func maxDepthOffset(
        pathCount: Int,
        attitude: DeviceAttitude,
        depthScale: CGFloat = GuillocheBlendLayer.defaultDepthScale
    ) -> CGSize {
        depthOffset(
            layer: max(pathCount - 1, 0),
            attitude: attitude,
            depthScale: depthScale
        )
    }
}
