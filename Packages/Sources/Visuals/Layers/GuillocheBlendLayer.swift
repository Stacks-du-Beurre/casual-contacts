import SwiftUI
import CoreModels
import DesignSystem

public struct GuillocheBlendLayer: View {

    public let paths: [Path]
    public let density: CCVisuals.Guilloche.LineDensity
    public let attitude: DeviceAttitude
    public let tint: Color

    /// Depth-scaling constant — controls how dramatically the stack fans out on tilt.
    /// 0.5pt per index step gives a subtle parallax without overwhelming the card.
    private static let depthScale: CGFloat = 0.5

    public init(
        paths: [Path],
        density: CCVisuals.Guilloche.LineDensity,
        attitude: DeviceAttitude,
        tint: Color = CCDesign.Colors.L4
    ) {
        self.paths = paths
        self.density = density
        self.attitude = attitude
        self.tint = tint
    }

    public var body: some View {
        ZStack {
            ForEach(paths.indices, id: \.self) { index in
                paths[index]
                    .stroke(tint.opacity(0.8), lineWidth: 0.5)
                    .offset(Self.offset(forPathIndex: index, attitude: attitude))
            }
        }
        .accessibilityHidden(true)
    }

    static func offset(forPathIndex index: Int, attitude: DeviceAttitude) -> CGSize {
        let depth = CGFloat(index + 1) * depthScale
        return CGSize(
            width: CGFloat(attitude.roll) * depth,
            height: CGFloat(attitude.pitch) * depth
        )
    }
}
