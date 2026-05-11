import SwiftUI
import DesignSystem
import Foundation

/// Top bar for the create-record sheet: Cancel on the left, centered title
/// (defaults to "PERSON"), `+ Person` disabled placeholder on the right.
/// 44pt tall. `+ Person` is rendered for visual parity with Figma; behavior
/// (2-person flow) is deferred to a later plan.
struct PersonTopNav: View {
    let title: String
    private let usesDefaultTitle: Bool
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    init(title: String? = nil, onCancel: @escaping () -> Void) {
        self.title = title ?? "PERSON"
        self.usesDefaultTitle = title == nil
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            // Heading — centered. 20% larger than Figma base 17pt.
            Text(localizedTitle)
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

    private var localizedTitle: String {
        usesDefaultTitle
            ? ModuleLocalization.string("PERSON", locale: locale)
            : title
    }
}
