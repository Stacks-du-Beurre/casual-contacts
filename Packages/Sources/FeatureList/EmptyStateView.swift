import SwiftUI
import CoreModels
import DesignSystem
import Visuals

public struct EmptyStateView: View {

    public let paths: any CardPathProvider

    public init(paths: any CardPathProvider) {
        self.paths = paths
    }

    public var body: some View {
        ZStack {
            CCDesign.Gradients.sunset
                .ignoresSafeArea()

            GuillocheRotationLayer(
                paths: Self.swirlPaths(from: paths.rotationPaths(for: "A")),
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

            Text("add the first person")
                .font(CCDesign.Typography.title)
                .foregroundStyle(.black)
                .padding(.horizontal, 6)
                .background {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        Color.white.opacity(0.05)
                    }
                }
                .accessibilityIdentifier("emptyStateTitle")
        }
    }

    // Per design-spec page 2: the A/Background filigree is the single A outline
    // rotated 5° at a time around the center of the 380×380 viewBox for a full
    // 72-step turn. The generated `rotationPaths` only contain one path; this
    // helper produces the full rotated stack for the empty-state swirl.
    private static func swirlPaths(from base: [Path]) -> [Path] {
        guard let single = base.first else { return [] }
        let center = CGPoint(x: 190, y: 190)
        let stepDegrees = 5.0
        let stepCount = Int(360.0 / stepDegrees)
        return (0..<stepCount).map { i in
            let radians = Double(i) * stepDegrees * .pi / 180.0
            let t = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: radians)
                .translatedBy(x: -center.x, y: -center.y)
            return single.applying(t)
        }
    }
}
