import SwiftUI
import DesignSystem

public struct SettingsSheet: View {

    @Environment(\.colorScheme) private var scheme
    @State private var syncEnabled = false
    @State private var advancedCardStackEnabled = false
    public let onAbout: () -> Void

    public init(onAbout: @escaping () -> Void) {
        self.onAbout = onAbout
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            groups
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SettingsPalette.sheetBackground(scheme))
        #if os(iOS)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationBackground(SettingsPalette.sheetBackground(scheme))
        #endif
    }

    private var header: some View {
        Text("Settings")
            .font(CCDesign.Typography.headline)
            .tracking(CCDesign.Typography.Tracking.headline)
            .textCase(.uppercase)
            .foregroundStyle(SettingsPalette.label(scheme))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .accessibilityAddTraits(.isHeader)
    }

    private var groups: some View {
        VStack(spacing: 24) {
            SettingsGroup {
                SettingsRow(label: "Sync data with iCloud", onTap: nil) {
                    Toggle("", isOn: $syncEnabled).labelsHidden()
                }
                SettingsDivider()
                SettingsRow(label: "Turn on advanced card stack", onTap: nil) {
                    Toggle("", isOn: $advancedCardStackEnabled).labelsHidden()
                }
            }

            SettingsGroup {
                SettingsRow(label: "Rate on the App Store", onTap: {}) {
                    trailingIcon(systemName: "star")
                }
                SettingsDivider()
                SettingsRow(label: "Recommended Casual Contacts", onTap: {}) {
                    trailingIcon(systemName: "square.and.arrow.up")
                }
            }

            SettingsGroup {
                SettingsRow(label: "About developers", onTap: onAbout) {
                    trailingIcon(systemName: "chevron.right", size: 14, weight: .semibold)
                }
            }
        }
    }

    private func trailingIcon(systemName: String, size: CGFloat = 18, weight: Font.Weight = .regular) -> some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: weight))
            .frame(width: 44, height: 43)
            .accessibilityHidden(true)
    }

    private var footer: some View {
        Text(versionString)
            .font(CCDesign.Typography.caption2)
            .foregroundStyle(SettingsPalette.footer(scheme))
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Casual Contacts Version \(version)"
    }
}
