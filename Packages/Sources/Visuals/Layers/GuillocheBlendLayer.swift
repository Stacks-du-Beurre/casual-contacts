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
    public static let defaultDepthScale: CGFloat = 0.5

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

    static func offset(
        forPathIndex index: Int,
        pathCount: Int = 0,
        attitude: DeviceAttitude,
        depthScale: CGFloat = GuillocheBlendLayer.defaultDepthScale,
        reversed: Bool = false
    ) -> CGSize {
        // Default ordering: first path moves least (depth 1), last path moves most.
        // Reversed: first path moves most, last path moves least — useful when the
        // outer lines should appear "anchored" and the inner lines swim through them.
        let step = reversed ? (pathCount - index) : (index + 1)
        let depth = CGFloat(step) * depthScale
        return CGSize(
            width: CGFloat(attitude.roll) * depth,
            height: CGFloat(attitude.pitch) * depth
        )
    }
}
