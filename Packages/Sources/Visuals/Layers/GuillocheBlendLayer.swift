import SwiftUI
import CoreModels
import DesignSystem

public struct GuillocheBlendLayer: View {

    public let paths: [Path]
    public let density: CCVisuals.Guilloche.LineDensity
    public let attitude: DeviceAttitude
    public let tint: Color
    public let depthScale: CGFloat

    /// Default depth-scaling — how many points the Nth path offsets per unit of
    /// roll/pitch. Empty-state hero uses a larger value (~1.0) for a more
    /// pronounced deep-dive; list-card density stays subtle at 0.5.
    public static let defaultDepthScale: CGFloat = 0.5

    public init(
        paths: [Path],
        density: CCVisuals.Guilloche.LineDensity,
        attitude: DeviceAttitude,
        tint: Color = CCDesign.Colors.L4,
        depthScale: CGFloat = GuillocheBlendLayer.defaultDepthScale
    ) {
        self.paths = paths
        self.density = density
        self.attitude = attitude
        self.tint = tint
        self.depthScale = depthScale
    }

    public var body: some View {
        ZStack {
            ForEach(paths.indices, id: \.self) { index in
                paths[index]
                    .stroke(tint.opacity(0.8), lineWidth: 0.5)
                    .offset(Self.offset(forPathIndex: index, attitude: attitude, depthScale: depthScale))
            }
        }
        .accessibilityHidden(true)
    }

    static func offset(
        forPathIndex index: Int,
        attitude: DeviceAttitude,
        depthScale: CGFloat = GuillocheBlendLayer.defaultDepthScale
    ) -> CGSize {
        let depth = CGFloat(index + 1) * depthScale
        return CGSize(
            width: CGFloat(attitude.roll) * depth,
            height: CGFloat(attitude.pitch) * depth
        )
    }
}
