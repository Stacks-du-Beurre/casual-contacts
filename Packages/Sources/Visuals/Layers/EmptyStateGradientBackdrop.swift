import SwiftUI
import CoreModels
import DesignSystem

/// Full-bleed sunset backdrop for the empty-state collection view.
///
/// Renders a single `CCDesign.Gradients.sunset` painting, centered in its
/// container and overscanned on the X axis so the gradient can drift with
/// gyro motion without revealing the viewport edge. Translation is expressed
/// as a fraction (`tuning.edgeReach`) of the available overscan slack, so
/// the far edge of the painting can reach the viewport edge at full tilt
/// but never pans past it. Pitch is ignored — X-only drift per design.
///
/// `attitude` arrives from `CoreMotionService` already baseline-relative and
/// tanh-saturated, so the gradient rests centered at launch pose and
/// auto-rebases along with every other attitude-driven effect.
public struct EmptyStateGradientBackdrop: View {

    public let attitude: DeviceAttitude

    private let tuning = EmptyStateGradientTuning.shared

    /// Horizontal overscan multiplier. Total slack on each side is
    /// `viewport * (overscan - 1) / 2`, which caps the maximum drift.
    /// At 3.0× on a 375pt viewport, slack per side is ~375pt.
    private static let overscan: CGFloat = 3.0

    public init(attitude: DeviceAttitude) {
        self.attitude = attitude
    }

    public var body: some View {
        GeometryReader { geo in
            let slack = geo.size.width * (Self.overscan - 1) / 2
            let reach = CGFloat(max(0, min(1, tuning.edgeReach)))
            let target = CGFloat(attitude.roll) * reach * slack
            let bounded = max(-slack, min(slack, target))
            ZStack {
                CCDesign.Gradients.sunset
                    .frame(
                        width: geo.size.width * Self.overscan,
                        height: geo.size.height
                    )
                    .offset(x: bounded, y: 0)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}
