import SwiftUI
import DesignSystem

/// Top bar for the create-record sheet: Cancel on the left, PERSON heading
/// centered, `+ Person` disabled placeholder on the right. 44pt tall.
/// `+ Person` is rendered for visual parity with Figma; behavior (2-person
/// flow) is deferred to a later plan.
struct PersonTopNav: View {
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            // Heading — centered.
            Text("PERSON")
                .font(CCDesign.Typography.headline)
                .tracking(CCDesign.Typography.Tracking.headline)
                .foregroundStyle(CCDesign.Colors.L2)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Button("Cancel", action: onCancel)
                    .font(.custom("CormorantInfant-SemiBold", size: 18))
                    .foregroundStyle(CCDesign.Colors.L0)
                    .accessibilityIdentifier("cancelCreateButton")

                Spacer()

                Text("+ Person")
                    .font(.custom("CormorantInfant-SemiBold", size: 18))
                    .foregroundStyle(CCDesign.Colors.L0)
                    .opacity(0.35)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
    }
}
