import SwiftUI
import CoreModels
import DesignSystem
import Visuals

public struct EmptyStateView: View {

    public let paths: any CardPathProvider
    public let onTap: () -> Void

    public init(paths: any CardPathProvider, onTap: @escaping () -> Void = {}) {
        self.paths = paths
        self.onTap = onTap
    }

    public var body: some View {
        GeometryReader { sceneGeo in
            ZStack {
                backdrop
                    .frame(width: sceneGeo.size.width, height: sceneGeo.size.height)

                Button(action: onTap) {
                    HologramPill(
                        hologram: .neon3,
                        backdropSize: sceneGeo.size,
                        coordinateSpaceName: Self.sceneCoordinateSpace,
                        backdrop: { backdrop },
                        content: {
                            HologramText("add the first person", font: CCDesign.Typography.title)
                                .padding(.horizontal, 6)
                        }
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

    @ViewBuilder
    private var backdrop: some View {
        ZStack {
            CCDesign.Gradients.sunset

            GuillocheRotationLayer(
                paths: GuillocheRotationLayer.swirlPaths(
                    from: paths.rotationPaths(for: "A").first
                ),
                opacity: 0.2,
                tint: .white
            )
            .frame(width: 380, height: 380)
            .accessibilityHidden(true)

            GuillocheBlendLayer(
                paths: paths.blendPaths(for: "A", shape: .polygon, density: .cards),
                density: .cards,
                attitude: .zero,
                tint: .white
            )
            .frame(width: 184, height: 160)
            .accessibilityHidden(true)
        }
    }

}
