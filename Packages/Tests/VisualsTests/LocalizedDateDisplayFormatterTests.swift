import CoreModels
import Foundation
import Testing
@testable import Visuals

@Suite struct LocalizedDateDisplayFormatterTests {

    // 2020-08-25 17:20 UTC. Keep assertions timezone-independent by forcing UTC.
    private let sampleDate = Date(timeIntervalSince1970: 1_598_376_000)
    private let utc = TimeZone(identifier: "UTC")!

    @Test func dateUsesProvidedDateLocale() {
        let formatted = LocalizedDateDisplayFormatter.formattedDate(
            sampleDate,
            timeZone: utc,
            dateLocale: Locale(identifier: "en_GB")
        )

        #expect(formatted == "25 Aug 2020")
    }

    @Test func timeUsesProvidedDateLocaleHourCycle() {
        let formatted = LocalizedDateDisplayFormatter.formattedTime(
            sampleDate,
            timeZone: utc,
            dateLocale: Locale(identifier: "en_GB")
        )

        #expect(formatted == "17:20")
    }

    @Test func timeLineSplitsDateLocaleFromLabelLocale() {
        let formatted = LocalizedDateDisplayFormatter.formattedTimeLine(
            sampleDate,
            timeOfDay: .sunset,
            timeZone: utc,
            labelLocale: Locale(identifier: "ru"),
            dateLocale: Locale(identifier: "en_GB"),
            timeOfDayDisplayName: { timeOfDay, locale in
                VisualsLocalization.timeOfDayDisplayName(timeOfDay, locale: locale)
            }
        )

        #expect(formatted == "Закат, 17:20")
    }
}
