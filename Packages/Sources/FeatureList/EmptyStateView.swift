import SwiftUI
import DesignSystem

public struct EmptyStateView: View {

    public init() {}

    public var body: some View {
        ZStack {
            CCDesign.Gradients.sunset
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Placeholder polygon glyph — a large rounded triangle.
                // Could later use the `A/Polygon` asset from the design-assets.
                RoundedRectangle(cornerRadius: 60)
                    .frame(width: 167, height: 145)
                    .foregroundStyle(.white.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 60)
                            .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                    )

                Text("No one here yet")
                    .font(CCDesign.Typography.title)
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("emptyStateTitle")

                Text("Tap + to record your first contact")
                    .font(CCDesign.Typography.descriptionSmall)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}
