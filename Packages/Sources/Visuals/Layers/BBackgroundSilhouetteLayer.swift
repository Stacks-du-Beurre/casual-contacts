import SwiftUI

/// Subtle letter-shaped contour behind the foreground guilloche blend on every
/// card. Per Figma `Cards/Full` → `B/Background` (node `15:1147`) and PDF §1
/// page 2, the silhouette is the letter's **single rotation outline** swept
/// around its center in 5° steps (72 copies, full 360°) — the same
/// construction `EmptyStateView` uses for its hero filigree, just dropped onto
/// every populated card at reduced opacity.
///
/// Layer stack: **gradient → rotation → silhouette → blend → zodiac → moon**.
/// Sitting *under* the blend letter is what gives the card its 3-D depth —
/// the silhouette reads as a shadow/echo behind the foreground glyph.
///
/// The incoming paths live in the 380×380 SVG viewBox coordinate space. We
/// draw into a parent-sized Canvas (no fixed `.frame`, so the layer never
/// pushes sibling views in the backdrop ZStack) and translate so the
/// viewBox center (190, 190) lines up with the Canvas center. Overflow is
/// clipped by `CardView`'s outer frame.
public struct BBackgroundSilhouetteLayer: View {

    public let paths: [Path]

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// - Parameter paths: the 72 swirled rotations of the letter's outline.
    ///   Typically `GuillocheRotationLayer.swirlPaths(from: rotationPaths(for: letter).first)`.
    public init(paths: [Path]) {
        self.paths = paths
    }

    public var body: some View {
        if reduceTransparency {
            // Translucent decorative layer — collapse to nothing under Reduce
            // Transparency per accessibility guidelines.
            EmptyView()
        } else {
            Canvas { context, size in
                // SVG viewBox is 380×380, centered at (190, 190). Offset so
                // the viewBox center lands at the canvas center, regardless
                // of the canvas's actual width/height.
                let dx = size.width / 2 - 190
                let dy = size.height / 2 - 190
                context.translateBy(x: dx, y: dy)
                let stroke = Color.white.opacity(0.13)
                for path in paths {
                    context.stroke(path, with: .color(stroke), lineWidth: 0.5)
                }
            }
            .accessibilityHidden(true)
        }
    }
}
