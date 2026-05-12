import CoreModels
import Foundation

public enum LocalizedDateDisplayFormatter {
    public static func formattedDate(
        _ date: Date,
        timeZone: TimeZone = .current,
        dateLocale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = dateLocale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        return formatter.string(from: date)
    }

    public static func formattedTime(
        _ date: Date,
        timeZone: TimeZone = .current,
        dateLocale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = dateLocale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("j:mm")
        return formatter.string(from: date)
    }

    public static func formattedTimeLine(
        _ date: Date,
        timeOfDay: TimeOfDay,
        timeZone: TimeZone = .current,
        labelLocale: Locale,
        dateLocale: Locale = .autoupdatingCurrent,
        timeOfDayDisplayName: (TimeOfDay, Locale) -> String
    ) -> String {
        let time = formattedTime(date, timeZone: timeZone, dateLocale: dateLocale)
        let label = timeOfDayDisplayName(timeOfDay, labelLocale)
        return "\(label), \(time)"
    }
}
