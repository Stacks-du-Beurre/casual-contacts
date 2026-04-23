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
                .tracking(CCDesign.Typography.Tracking.description)
                .foregroundStyle(SettingsPalette.label(scheme))
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
                .foregroundStyle(SettingsPalette.icon(scheme))
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 43)
        .contentShape(Rectangle())

        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

/// Settings row with a trailing toggle. Uses SwiftUI's native `Toggle`-with-label
/// composition so the entire row area is tappable (vs. `SettingsRow` holding a
/// `Toggle` in its trailing slot, which only responds to hits on the knob).
struct SettingsToggleRow: View {
    @Environment(\.colorScheme) private var scheme
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .font(CCDesign.Typography.description)
                .tracking(CCDesign.Typography.Tracking.description)
                .foregroundStyle(SettingsPalette.label(scheme))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tint(SettingsPalette.label(scheme))
        .padding(.horizontal, 16)
        .frame(minHeight: 43)
    }
}

struct SettingsGroup<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: String?
    @ViewBuilder let content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(CCDesign.Typography.caption2)
                    .tracking(CCDesign.Typography.Tracking.headline)
                    .textCase(.uppercase)
                    .foregroundStyle(SettingsPalette.footer(scheme))
                    .padding(.horizontal, 16)
                    .accessibilityAddTraits(.isHeader)
            }
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
