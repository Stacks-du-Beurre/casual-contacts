import SwiftUI
import DesignSystem

/// Sort option backing the Default Sorting sheet. `advanced` is surfaced in the
/// sheet but its destination screen (`L_Advanced_Sorting`) is deferred to v1.1+.
public enum SortOption: Sendable, Hashable, CaseIterable {
    case alphabetical
    case dateCreated
    case timeCreated
}

/// Bottom-anchored action sheet matching Figma `L_Default_Sorting` (`209:9048`)
/// and `D_Default_Sorting` (`278:10897`). Two 14pt-radius cards:
///   1. Options card with rows divided by 1pt hairlines
///   2. Cancel card separated by an 8pt gap
/// Tap a row → sets `selected` and dismisses. Tap `Advanced sorting` calls
/// `onAdvanced` (placeholder — destination screen is deferred). Tap outside or
/// tap Cancel calls `onDismiss`.
struct DefaultSortingSheet: View {
    @Binding var selected: SortOption
    let onAdvanced: () -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // Card fills + dividers derive from the populated collection-view tokens
    // (L2/D3 card, L3/D0 hairline) so the sheet matches the list it lives in.
    private var cardFill: Color {
        colorScheme == .dark ? CCDesign.Colors.D3 : CCDesign.Colors.L2
    }

    private var rowLabelColor: Color {
        colorScheme == .dark ? CCDesign.Colors.L2 : CCDesign.Colors.D4
    }

    private var dividerColor: Color {
        colorScheme == .dark ? CCDesign.Colors.D0 : CCDesign.Colors.L3
    }

    private var cancelColor: Color {
        colorScheme == .dark ? CCDesign.Colors.L2 : .black
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
                .transition(.opacity)

            VStack(spacing: 8) {
                optionsCard
                cancelCard
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom))
        }
        .accessibilityAddTraits(.isModal)
    }

    private var optionsCard: some View {
        VStack(spacing: 0) {
            row("Default (Alphabetically)", option: .alphabetical)
            divider
            row("Date Created", option: .dateCreated)
            divider
            row("Time Created", option: .timeCreated)
            divider
            advancedRow
        }
        .background(cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var cancelCard: some View {
        Button(action: onDismiss) {
            Text("cancel")
                .font(CCDesign.Typography.headline)
                .tracking(CCDesign.Typography.Tracking.headline)
                .foregroundStyle(cancelColor)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel("Cancel")
    }

    private func row(_ title: String, option: SortOption) -> some View {
        Button {
            selected = option
            onDismiss()
        } label: {
            rowContent(title: title, isSelected: selected == option)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected == option ? .isSelected : [])
    }

    private var advancedRow: some View {
        Button(action: onAdvanced) {
            rowContent(title: "Advanced sorting", isSelected: false)
        }
        .buttonStyle(.plain)
    }

    private func rowContent(title: String, isSelected: Bool) -> some View {
        ZStack {
            Text(title)
                .font(CCDesign.Typography.description)
                .tracking(CCDesign.Typography.Tracking.description)
                .foregroundStyle(rowLabelColor)
                .frame(maxWidth: .infinity)

            if isSelected {
                HStack {
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(rowLabelColor)
                        .padding(.trailing, 24)
                }
            }
        }
        .frame(height: 56)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        dividerColor
            .frame(height: 1)
    }
}
