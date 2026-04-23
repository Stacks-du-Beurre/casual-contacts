import SwiftUI
import DesignSystem

/// Top bar for the create-record sheet: Cancel on the left, PERSON heading
/// centered, `+ Person` disabled placeholder on the right. 44pt tall.
/// `+ Person` is rendered for visual parity with Figma; behavior (2-person
/// flow) is deferred to a later plan.
struct PersonTopNav: View {
    let title: String
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(title: String = "PERSON", onCancel: @escaping () -> Void) {
        self.title = title
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            // Heading — centered. 20% larger than Figma base 17pt.
            Text(title)
                .font(.custom("CormorantSC-Bold", size: 20.4))
                .tracking(CCDesign.Typography.Tracking.headline)
                .foregroundStyle(CCDesign.Colors.L2)
                .accessibilityAddTraits(.isHeader)

            HStack {
                // Cancel — 20% larger than Figma base 18pt.
                Button {
                    onCancel()
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.custom("CormorantInfant-SemiBold", size: 21.6))
                        .foregroundStyle(CCDesign.Colors.L0)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cancelCreateButton")

                Spacer()

                Text("+ Person")
                    .font(.custom("CormorantInfant-SemiBold", size: 21.6))
                    .foregroundStyle(CCDesign.Colors.L0)
                    .opacity(0.35)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
    }
}
