import SwiftUI
import CoreModels
import DesignSystem

public struct GuillocheRotationLayer: View {

    public let paths: [Path]
    public let opacity: Double
    public let tint: Color

    public init(paths: [Path], opacity: Double = 0.2, tint: Color = CCDesign.Colors.L4) {
        self.paths = paths
        self.opacity = opacity
        self.tint = tint
    }

    public var body: some View {
        Canvas { context, size in
            for path in paths {
                context.stroke(path, with: .color(tint.opacity(opacity)), lineWidth: 0.5)
            }
        }
        .accessibilityHidden(true)
    }
}
