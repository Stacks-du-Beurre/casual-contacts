import SwiftUI
import Foundation
import CoreModels
import DesignSystem

/// 40pt glass strip under the card. Left half: two-line uppercase address +
/// hologram-masked pin glyph. Right half: two-line date + `{timeOfDay}, h:mm a`.
/// Center vertical hairline separator.
struct LocationTimeStrip: View {

    let location: LocationInfo?
    let createdAt: Date
    let timeOfDay: TimeOfDay

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

                Image(systemName: "location.fill")
                    .font(.system(size: 10))
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
                Text(Self.formattedTimeLine(createdAt, timeOfDay: timeOfDay, timeZone: zone))
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
    }

    // MARK: - Formatters

    nonisolated static func formattedDate(_ date: Date, timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    nonisolated static func formattedTimeLine(_ date: Date, timeOfDay: TimeOfDay, timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        let time = f.string(from: date)
        let label = timeOfDay.rawValue.capitalized
        return "\(label), \(time)"
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
