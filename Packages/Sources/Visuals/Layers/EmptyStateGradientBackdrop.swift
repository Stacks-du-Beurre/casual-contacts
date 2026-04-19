import SwiftUI
import CoreModels
import DesignSystem

/// Full-bleed sunset backdrop for the empty-state collection view.
///
/// Renders `CCDesign.Gradients.sunset` at its natural aspect, scaled to fill
/// the viewport (cover). Horizontal drift is bound by the exact slack the
/// image contributes at that viewport size — no arbitrary overscan. At
/// `edgeReach = 1.0` and `|roll| = 1`, the image's edge reaches the viewport
/// edge and no further; at lower reach it stops short. Pitch is ignored —
/// X-only drift per design.
///
/// `attitude` arrives from `CoreMotionService` already baseline-relative and
/// tanh-saturated, so the gradient rests centered at launch pose and
/// auto-rebases along with every other attitude-driven effect.
public struct EmptyStateGradientBackdrop: View {

    public let attitude: DeviceAttitude

    private let tuning = EmptyStateGradientTuning.shared

    /// Natural pixel size of Sunset.png (see
    /// `Packages/Sources/DesignSystem/Resources/Gradients.xcassets/Sunset.imageset/Sunset.png`).
    /// Used to compute the exact horizontal slack available at each viewport
    /// size when the image is scaled-to-fill. Kept in sync with the asset
    /// manually — if the PNG is re-exported at a different aspect this value
    /// must be updated.
    static let imageSize = CGSize(width: 689, height: 416)

    public init(attitude: DeviceAttitude) {
        self.attitude = attitude
    }

    public var body: some View {
        GeometryReader { geo in
            let geometry = Self.scaledGeometry(viewport: geo.size, imageSize: Self.imageSize)
            let reach = CGFloat(max(0, min(1, tuning.edgeReach)))
            let offset = CGFloat(attitude.roll) * reach * geometry.slack
            let bounded = max(-geometry.slack, min(geometry.slack, offset))
            ZStack {
                CCDesign.Gradients.sunset
                    .frame(width: geometry.width, height: geometry.height)
                    .offset(x: bounded, y: 0)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    /// Pure geometry helper: given a viewport size and the source image's
    /// intrinsic size, returns the dimensions of the scaled-to-fill image
    /// along with the horizontal slack (per side) available for drift.
    /// Slack is 0 if the image's aspect ratio is narrower-or-equal than
    /// the viewport's (width becomes the binding axis, leaving no X room).
    static func scaledGeometry(viewport: CGSize, imageSize: CGSize) -> (width: CGFloat, height: CGFloat, slack: CGFloat) {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return (viewport.width, viewport.height, 0)
        }
        let scale = max(viewport.width / imageSize.width, viewport.height / imageSize.height)
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        let slack = max(0, (scaledWidth - viewport.width) / 2)
        return (scaledWidth, scaledHeight, slack)
    }
}
