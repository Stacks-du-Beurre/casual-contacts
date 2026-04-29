import SwiftUI
import DesignSystem

public struct LocationPermissionPrimer: View {
    @Environment(\.colorScheme) private var scheme

    private let onAccept: () -> Void
    private let onDecline: () -> Void

    public init(
        onAccept: @escaping () -> Void,
        onDecline: @escaping () -> Void
    ) {
        self.onAccept = onAccept
        self.onDecline = onDecline
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                Text("USE LOCATION?")
                    .font(CCDesign.Typography.headline)
                    .tracking(CCDesign.Typography.Tracking.headline)
                    .textCase(.uppercase)
                    .foregroundStyle(labelColor)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("Location helps Casual Contacts sort cards by where you met people, so nearby names can surface when you open the app.")
                    .font(CCDesign.Typography.description)
                    .tracking(CCDesign.Typography.Tracking.description)
                    .foregroundStyle(labelColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    Button(action: onAccept) {
                        Text("Use Location")
                            .font(CCDesign.Typography.description)
                            .tracking(CCDesign.Typography.Tracking.description)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(primaryButtonTextColor)
                    .background(primaryButtonColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityIdentifier("locationPrimerAcceptButton")

                    Button(action: onDecline) {
                        Text("Not Now")
                            .font(CCDesign.Typography.description)
                            .tracking(CCDesign.Typography.Tracking.description)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(labelColor)
                    .background(secondaryButtonColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    }
                    .accessibilityIdentifier("locationPrimerDeclineButton")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: 360)
            .background(panelColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(sheetBackground.ignoresSafeArea())
    }

    private var sheetBackground: Color {
        scheme == .dark ? CCDesign.Colors.D3 : CCDesign.Colors.L2
    }

    private var panelColor: Color {
        scheme == .dark ? CCDesign.Colors.D2 : CCDesign.Colors.L1
    }

    private var labelColor: Color {
        scheme == .dark ? CCDesign.Colors.L2 : CCDesign.Colors.D4
    }

    private var borderColor: Color {
        scheme == .dark ? CCDesign.Colors.D1 : CCDesign.Colors.L3
    }

    private var primaryButtonColor: Color {
        scheme == .dark ? CCDesign.Colors.L2 : CCDesign.Colors.D4
    }

    private var primaryButtonTextColor: Color {
        scheme == .dark ? CCDesign.Colors.D4 : CCDesign.Colors.L2
    }

    private var secondaryButtonColor: Color {
        scheme == .dark ? CCDesign.Colors.D3 : CCDesign.Colors.L2
    }
}
