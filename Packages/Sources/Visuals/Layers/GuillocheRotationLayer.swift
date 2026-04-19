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

    /// Produces the full 72-step (5° per step) rotation filigree of a single
    /// letter outline — the construction the designer used for every letter's
    /// `X/Background` silhouette (per PDF §1, page 2). Both the empty-state
    /// hero and the card-level `BBackgroundSilhouetteLayer` consume this.
    ///
    /// - Parameters:
    ///   - base: the letter's single-outline rotation path (usually
    ///     `rotationPaths(for: letter).first`).
    ///   - center: rotation origin, in the same coordinate space as `base`.
    ///     Default `(190, 190)` matches the 380×380 viewBox the outlines ship in.
    ///   - stepDegrees: angle between successive copies. Default `5°` (72 steps).
    public static func swirlPaths(
        from base: Path?,
        center: CGPoint = CGPoint(x: 190, y: 190),
        stepDegrees: Double = 5.0
    ) -> [Path] {
        guard let base else { return [] }
        let stepCount = Int(360.0 / stepDegrees)
        return (0..<stepCount).map { i in
            let radians = Double(i) * stepDegrees * .pi / 180.0
            let t = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: radians)
                .translatedBy(x: -center.x, y: -center.y)
            return base.applying(t)
        }
    }
}
