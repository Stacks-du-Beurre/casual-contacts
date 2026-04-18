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
            Image(assetName, bundle: .module)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        }
    }
}
