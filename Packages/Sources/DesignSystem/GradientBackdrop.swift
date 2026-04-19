import SwiftUI

public extension CCDesign {
    /// Bitmap-backed full-bleed time-of-day gradient. Renders the designer's
    /// PNG from `Gradients.xcassets` stretched to fill the frame (non-uniform
    /// scaling) so both color axes of the painting reach the viewport edges.
    /// Per `docs/CC Design Specifications.pdf §2`, gradients are hand-authored
    /// paintings, not procedural ramps — this view guarantees the canonical source.
    struct GradientBackdrop: View, Equatable, Hashable, Sendable {
        nonisolated public let assetName: String

        nonisolated public init(assetName: String) {
            self.assetName = assetName
        }

        public var body: some View {
            Image(assetName, bundle: .module)
                .resizable()
                .accessibilityHidden(true)
        }
    }
}
