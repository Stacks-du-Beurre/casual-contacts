import SwiftUI

public extension CCDesign {
    /// Bitmap-backed full-bleed time-of-day gradient. Renders the designer's
    /// PNG from `Gradients.xcassets` via `Image(name:bundle:).resizable().scaledToFill()`.
    /// Per `docs/CC Design Specifications.pdf §2`, gradients are hand-authored
    /// paintings, not procedural ramps — this view guarantees the canonical source.
    struct GradientBackdrop: View, Equatable, Hashable, Sendable {
        nonisolated public let assetName: String

        nonisolated public init(assetName: String) {
            self.assetName = assetName
        }

        public var body: some View {
            // Wrap the `scaledToFill` image in a flex `Color.clear` host and
            // clip the overflow to that host's bounds. Without the wrapper,
            // `scaledToFill` propagates an oversized ideal width (matching the
            // PNG's aspect) up through any ZStack it lives in, ballooning the
            // parent's layout when the parent aspect doesn't match the
            // gradient's. `Color.clear` is flex-flex, so the ideal size the
            // ZStack sees is the proposed size — not the scaled image's.
            Color.clear
                .overlay {
                    Image(assetName, bundle: .module)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .accessibilityHidden(true)
        }
    }
}
