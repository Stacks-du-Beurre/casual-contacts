import SwiftUI
import DesignSystem

enum SettingsPalette {
    static func sheetBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? CCDesign.Colors.D3 : CCDesign.Colors.L2
    }
    static func rowBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? CCDesign.Colors.D2 : CCDesign.Colors.L1
    }
    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? CCDesign.Colors.D1 : CCDesign.Colors.L3
    }
    static func label(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? CCDesign.Colors.L2 : CCDesign.Colors.D4
    }
    static func icon(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? CCDesign.Colors.L3 : CCDesign.Colors.D4
    }
    static func footer(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? CCDesign.Colors.L4 : CCDesign.Colors.D0
    }
}

struct SettingsRow<Trailing: View>: View {
    @Environment(\.colorScheme) private var scheme
    let label: String
    let onTap: (() -> Void)?
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        let content = HStack(spacing: 12) {
            Text(label)
                .font(CCDesign.Typography.description)
                .fontWeight(.semibold)
                .tracking(CCDesign.Typography.Tracking.description)
                .foregroundStyle(SettingsPalette.label(scheme))
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
                .foregroundStyle(SettingsPalette.icon(scheme))
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 43)

        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
        } else {
            content
        }
    }
}

struct SettingsGroup<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity)
            .background(SettingsPalette.rowBackground(scheme))
            .overlay(alignment: .top) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(SettingsPalette.border(scheme))
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(SettingsPalette.border(scheme))
            }
    }
}

struct SettingsDivider: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundStyle(SettingsPalette.border(scheme))
            .padding(.leading, 16)
    }
}
