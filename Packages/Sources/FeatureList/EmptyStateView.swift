import SwiftUI
import CoreModels
import DesignSystem
import Foundation
import Visuals

public struct EmptyStateView: View {

    public let paths: any CardPathProvider
    public let timeOfDay: TimeOfDay
    public let attitude: DeviceAttitude
    public let onTap: () -> Void

    @Bindable private var blendTuning = CardBlendTuning.shared
    @Bindable private var elementDepthTuning = CardElementDepthTuning.shared
    @Environment(\.locale) private var locale

    public init(
        paths: any CardPathProvider,
        timeOfDay: TimeOfDay,
        attitude: DeviceAttitude = .zero,
        onTap: @escaping () -> Void = {}
    ) {
        self.paths = paths
        self.timeOfDay = timeOfDay
        self.attitude = attitude
        self.onTap = onTap
    }

    public var body: some View {
        GeometryReader { sceneGeo in
            ZStack {
                backdrop
                    .frame(width: sceneGeo.size.width, height: sceneGeo.size.height)

                Button(action: onTap) {
                    HologramText(
                        ModuleLocalization.string("add the first person", locale: locale),
                        font: Self.scaledTitleFont(canvasWidth: sceneGeo.size.width),
                        attitude: attitude,
                        backdropSize: sceneGeo.size,
                        coordinateSpaceName: Self.sceneCoordinateSpace,
                        backdrop: { backdrop }
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("emptyStateTitle")
                .accessibilityLabel(ModuleLocalization.text("add the first person", locale: locale))
                .accessibilityHint(ModuleLocalization.text("Opens the new contact form", locale: locale))
            }
            .coordinateSpace(.named(Self.sceneCoordinateSpace))
        }
        .ignoresSafeArea()
    }

    private static let sceneCoordinateSpace = "EmptyStateScene"

    /// Scale the 33pt Figma title proportionally to the 375pt iPhone 11 Pro
    /// canvas it was designed against. Cap at 1.3× so iPad-width screens don't
    /// blow the pill into a headline.
    private static func scaledTitleFont(canvasWidth: CGFloat) -> Font {
        let scale = min(max(canvasWidth / 375, 1.0), 1.3)
        return Font.custom("CormorantSC-SemiBold", size: 33 * scale, relativeTo: .largeTitle)
    }

    @ViewBuilder
    private var backdrop: some View {
        let blendPaths = paths.blendPaths(for: "A", shape: .polygon, density: .cards)
        let blendDepthScale: CGFloat = 10.0
        // In translate mode, couple the swirl's x/y movement to the blend
        // stack's most-shifted path. In rotate mode, keep it anchored so it
        // does not fight the attitude-driven rotation.
        let coupledOffset = GuillocheBlendLayer.maxDepthOffset(
            pathCount: blendPaths.count,
            attitude: attitude,
            depthScale: blendDepthScale,
            reverseDepthOrder: blendTuning.reverseDepthOrder,
            reverseMotionDirection: blendTuning.reverseMotionDirection,
            movementScaleX: blendTuning.guillocheMovementScaleX,
            movementScaleY: blendTuning.guillocheMovementScaleY,
            perspectiveAmount: elementDepthTuning.perspectiveAmount
        )
        let movesRotationGuilloche = blendTuning.rotationGuillocheMovesInsteadOfRotates
        let rotationGuillocheAttitude: DeviceAttitude = movesRotationGuilloche ? .zero : attitude
        let rotationGuillocheOffset: CGSize = movesRotationGuilloche ? coupledOffset : .zero

        ZStack {
            EmptyStateGradientBackdrop(timeOfDay: timeOfDay, attitude: attitude)

            GuillocheRotationLayer(
                paths: GuillocheRotationLayer.swirlPaths(
                    from: paths.rotationPaths(for: "A").first
                ),
                tint: .white,
                attitude: rotationGuillocheAttitude,
                usage: .emptyState
            )
            .frame(width: 380, height: 380)
            .offset(rotationGuillocheOffset)
            .accessibilityHidden(true)

            // Per design spec §"How to get the deep-dive effect": each of the
            // blend paths is a separate exported line; offset each by (x, y)
            // driven by the gyroscope attitude — `GuillocheBlendLayer` does
            // the per-index depth-scaled offset internally.
            GuillocheBlendLayer(
                paths: blendPaths,
                density: .cards,
                attitude: attitude,
                tint: .white,
                depthScale: blendDepthScale,
                reversed: true,
                reverseDepthOrder: blendTuning.reverseDepthOrder,
                reverseMotionDirection: blendTuning.reverseMotionDirection,
                movementScaleX: blendTuning.guillocheMovementScaleX,
                movementScaleY: blendTuning.guillocheMovementScaleY,
                perspectiveAmount: elementDepthTuning.perspectiveAmount
            )
            .frame(width: 184, height: 160)
            .accessibilityHidden(true)
        }
    }

}
