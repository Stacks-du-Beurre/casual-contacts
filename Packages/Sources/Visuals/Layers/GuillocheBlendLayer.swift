import SwiftUI
import CoreModels
import DesignSystem

public struct GuillocheBlendLayer: View {

    public let paths: [Path]
    public let density: CCVisuals.Guilloche.LineDensity
    public let attitude: DeviceAttitude
    public let tint: Color
    public let depthScale: CGFloat
    public let reversed: Bool

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
        reversed: Bool = false
    ) {
        self.paths = paths
        self.density = density
        self.attitude = attitude
        self.tint = tint
        self.depthScale = depthScale
        self.reversed = reversed
    }

    public var body: some View {
        ZStack {
            ForEach(paths.indices, id: \.self) { index in
                paths[index]
                    .stroke(tint.opacity(0.8), lineWidth: 0.5)
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
