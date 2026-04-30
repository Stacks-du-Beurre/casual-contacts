import SwiftUI
import DesignSystem

public struct LocationPermissionPrimer: View {
    @Environment(\.colorScheme) private var scheme

    private let onContinue: () -> Void

    public init(
        onContinue: @escaping () -> Void
    ) {
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                Text("LOCATION ACCESS")
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
                    Button(action: onContinue) {
                        Text("Continue")
                            .font(CCDesign.Typography.description)
                            .tracking(CCDesign.Typography.Tracking.description)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(primaryButtonTextColor)
                    .background(primaryButtonColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityIdentifier("locationPrimerContinueButton")
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

}
