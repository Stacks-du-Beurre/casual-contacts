import SwiftUI
import CoreModels
import DesignSystem
import Visuals

public struct EmptyStateView: View {

    public let paths: any CardPathProvider
    public let attitude: DeviceAttitude
    public let onTap: () -> Void

    public init(
        paths: any CardPathProvider,
        attitude: DeviceAttitude = .zero,
        onTap: @escaping () -> Void = {}
    ) {
        self.paths = paths
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
                        "add the first person",
                        font: Self.scaledTitleFont(canvasWidth: sceneGeo.size.width),
                        attitude: attitude,
                        backdropSize: sceneGeo.size,
                        coordinateSpaceName: Self.sceneCoordinateSpace,
                        backdrop: { backdrop }
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("emptyStateTitle")
                .accessibilityLabel("add the first person")
                .accessibilityHint("Opens the new contact form")
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
        ZStack {
            EmptyStateGradientBackdrop(attitude: attitude)

            GuillocheRotationLayer(
                paths: GuillocheRotationLayer.swirlPaths(
                    from: paths.rotationPaths(for: "A").first
                ),
                opacity: 0.2,
                tint: .white
            )
            .frame(width: 380, height: 380)
            .accessibilityHidden(true)

            // Per design spec §"How to get the deep-dive effect": each of the
            // blend paths is a separate exported line; offset each by (x, y)
            // driven by the gyroscope attitude — `GuillocheBlendLayer` does
            // the per-index depth-scaled offset internally.
            GuillocheBlendLayer(
                paths: paths.blendPaths(for: "A", shape: .polygon, density: .cards),
                density: .cards,
                attitude: attitude,
                tint: .white,
                depthScale: 10.0,
                reversed: true
            )
            .frame(width: 184, height: 160)
            .accessibilityHidden(true)
        }
    }

}
