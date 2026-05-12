import SwiftUI
import Foundation
import CoreModels
import DesignSystem
import Visuals

/// 40pt glass strip under the card. Left half: two-line uppercase address +
/// hologram-masked pin glyph. Right half: two-line date + `{timeOfDay}, h:mm a`.
/// Center vertical hairline separator.
struct LocationTimeStrip: View {

    let location: LocationInfo?
    let createdAt: Date
    let timeOfDay: TimeOfDay
    @Environment(\.locale) private var locale

    var body: some View {
        let (addrLine1, addrLine2) = Self.splitAddress(location?.label)
        let zone = TimeZone.current

        HStack(spacing: 0) {
            // Left half — address + pin.
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(addrLine1)
                    if !addrLine2.isEmpty {
                        Text(addrLine2)
                    }
                }
                .font(CCDesign.Typography.caption1)
                .tracking(CCDesign.Typography.Tracking.caption1)
                .foregroundStyle(CCDesign.Colors.L0)

                Spacer(minLength: 0)

                Image("LocationPin", bundle: CCDesign.bundle)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(CCDesign.Colors.L0)
                    .opacity(0.75)
                    .padding(.trailing, 8)
            }
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            // Vertical hairline separator.
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 1, height: 38)

            // Right half — date + time.
            VStack(alignment: .trailing, spacing: 0) {
                Text(Self.formattedDate(createdAt, timeZone: zone))
                Text(Self.formattedTimeLine(createdAt, timeOfDay: timeOfDay, timeZone: zone, labelLocale: locale))
            }
            .font(CCDesign.Typography.caption2)
            .foregroundStyle(CCDesign.Colors.L0)
            .padding(.top, 7)
            .padding(.trailing, 15)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(height: 40)
        .background(Color.white.opacity(0.1))
        .overlay(
            Rectangle().stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Formatters

    nonisolated static func formattedDate(
        _ date: Date,
        timeZone: TimeZone,
        dateLocale: Locale = .autoupdatingCurrent
    ) -> String {
        LocalizedDateDisplayFormatter.formattedDate(date, timeZone: timeZone, dateLocale: dateLocale)
    }

    nonisolated static func formattedTimeLine(
        _ date: Date,
        timeOfDay: TimeOfDay,
        timeZone: TimeZone,
        labelLocale: Locale,
        dateLocale: Locale = .autoupdatingCurrent
    ) -> String {
        LocalizedDateDisplayFormatter.formattedTimeLine(
            date,
            timeOfDay: timeOfDay,
            timeZone: timeZone,
            labelLocale: labelLocale,
            dateLocale: dateLocale,
            timeOfDayDisplayName: Self.timeOfDayDisplayName
        )
    }

    nonisolated static func timeOfDayDisplayName(_ timeOfDay: TimeOfDay, locale: Locale) -> String {
        ModuleLocalization.timeOfDayDisplayName(timeOfDay, locale: locale)
    }

    nonisolated static func splitAddress(_ raw: String?) -> (String, String) {
        guard let raw, !raw.isEmpty else { return ("", "") }
        let upper = raw.uppercased()
        guard let commaRange = upper.range(of: ",") else {
            return (upper, "")
        }
        let line1 = String(upper[..<commaRange.upperBound])
        let line2 = String(upper[commaRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        return (line1, line2)
    }
}
