import SwiftUI
import DesignSystem

public enum SettingsPalette {
    public static func sheetBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? CCDesign.Colors.D3 : CCDesign.Colors.L2
    }
    public static func rowBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? CCDesign.Colors.D2 : CCDesign.Colors.L1
    }
    public static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? CCDesign.Colors.D1 : CCDesign.Colors.L3
    }
    public static func label(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? CCDesign.Colors.L2 : CCDesign.Colors.D4
    }
    public static func icon(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? CCDesign.Colors.L3 : CCDesign.Colors.D4
    }
    public static func footer(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? CCDesign.Colors.L4 : CCDesign.Colors.D0
    }
}

public struct SettingsRow<Trailing: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale
    let label: String
    let onTap: (() -> Void)?
    @ViewBuilder let trailing: () -> Trailing

    public init(label: String, onTap: (() -> Void)? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.label = label; self.onTap = onTap; self.trailing = trailing
    }

    public var body: some View {
        let content = HStack(spacing: 12) {
            FeatureSettingsLocalization.text(label, locale: locale)
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
public struct SettingsToggleRow: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale
    let label: String
    @Binding var isOn: Bool

    public init(label: String, isOn: Binding<Bool>) { self.label = label; self._isOn = isOn }

    public var body: some View {
        Toggle(isOn: $isOn) {
            FeatureSettingsLocalization.text(label, locale: locale)
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

public struct SettingsGroup<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale
    let title: String?
    @ViewBuilder let content: () -> Content

    public init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                FeatureSettingsLocalization.text(title, locale: locale)
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

public struct SettingsDivider: View {
    public init() {}
    @Environment(\.colorScheme) private var scheme
    public var body: some View {
        Rectangle()
            .frame(height: 1)
            .foregroundStyle(SettingsPalette.border(scheme))
            .padding(.leading, 16)
    }
}
