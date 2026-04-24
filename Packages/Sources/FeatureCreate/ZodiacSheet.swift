#if os(iOS)
import SwiftUI
import UIKit
import CoreModels
import DesignSystem
import Visuals

/// Popover presented when the user taps "+ Add Zodiac" in the create flow.
/// Two columns × six rows of zodiac buttons, each showing the small
/// `CreateZodiacSymbolBadge` holographic glyph paired with the sign name in
/// the same Caption2/white treatment used on the card's zodiac label.
struct ZodiacSheet: View {

    let attitude: DeviceAttitude
    /// Resolved by the presenter (outside the popover, where SwiftUI's
    /// `colorScheme` environment still reflects the system). Controls which
    /// `Moon_Background*` asset the picker badges render — the light variant
    /// is only shown when this is `true`.
    let isLightAppearance: Bool
    let onSelect: (ZodiacSign) -> Void
    let onClose: () -> Void

    /// Row-major split of `ZodiacSign.allCases` into two columns of six, so
    /// the left column holds the even-indexed signs (aries, gemini, leo,
    /// libra, sagittarius, aquarius) and the right column the odd-indexed
    /// (taurus, cancer, virgo, scorpio, capricorn, pisces).
    private static let leftColumn: [ZodiacSign] = ZodiacSign.allCases
        .enumerated()
        .filter { $0.offset.isMultiple(of: 2) }
        .map(\.element)

    private static let rightColumn: [ZodiacSign] = ZodiacSign.allCases
        .enumerated()
        .filter { !$0.offset.isMultiple(of: 2) }
        .map(\.element)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            column(signs: Self.leftColumn)
            column(signs: Self.rightColumn)
        }
        .padding(16)
        .presentationCompactAdaptation(.popover)
    }

    @ViewBuilder
    private func column(signs: [ZodiacSign]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(signs, id: \.self) { sign in
                cell(for: sign)
            }
        }
    }

    private var backgroundAssetName: String {
        isLightAppearance ? "Moon_Background_Light" : "Moon_Background"
    }

    @ViewBuilder
    private func cell(for sign: ZodiacSign) -> some View {
        Button {
            onSelect(sign)
            onClose()
        } label: {
            HStack(alignment: .center, spacing: 8) {
                CreateZodiacSymbolBadge(
                    sign: sign,
                    attitude: attitude,
                    backgroundAssetName: backgroundAssetName
                )
                .frame(width: 35, height: 32)
                Text(sign.rawValue.capitalized)
                    .font(CCDesign.Typography.caption2)
                    .foregroundStyle(Color(uiColor: .label))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("zodiacPickerButton_\(sign.rawValue)")
    }
}
#endif
