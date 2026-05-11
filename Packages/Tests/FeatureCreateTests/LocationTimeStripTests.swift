import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import FeatureCreate

@Suite struct LocationTimeStripTests {

    // 2020-08-25 17:20 UTC. Keep assertions timezone-independent by forcing UTC.
    private let sampleDate = Date(timeIntervalSince1970: 1_598_376_000)

    @Test func formatsDateAsMMMdYYYY() {
        let formatted = LocationTimeStrip.formattedDate(
            sampleDate,
            timeZone: TimeZone(identifier: "UTC")!,
            locale: Locale(identifier: "en")
        )
        #expect(formatted == "Aug 25, 2020")
    }

    @Test func formatsTimeWithLocaleAwareTimeOfDay() {
        let formatted = LocationTimeStrip.formattedTimeLine(
            sampleDate,
            timeOfDay: .sunset,
            timeZone: TimeZone(identifier: "UTC")!,
            locale: Locale(identifier: "en")
        )
        #expect(formatted.contains("Sunset"))
        #expect(formatted.contains("5:20"))
    }

    @Test func timeLineLocalizesTimeOfDay() {
        let formatted = LocationTimeStrip.formattedTimeLine(
            sampleDate,
            timeOfDay: .midday,
            timeZone: TimeZone(identifier: "UTC")!,
            locale: Locale(identifier: "uk")
        )
        #expect(formatted.contains("Полудень"))
    }

    @Test func timeOfDayDisplayNamesUseProvidedLocale() {
        #expect(LocationTimeStrip.timeOfDayDisplayName(.sunset, locale: Locale(identifier: "ru")) == "Закат")
        #expect(LocationTimeStrip.timeOfDayDisplayName(.midnight, locale: Locale(identifier: "uk")) == "Північ")
    }

    @Test func splitsAddressAtFirstComma() {
        let (line1, line2) = LocationTimeStrip.splitAddress("1200 Treat Ave, San Francisco")
        #expect(line1 == "1200 TREAT AVE,")
        #expect(line2 == "SAN FRANCISCO")
    }

    @Test func splitAddressHandlesSingleLine() {
        let (line1, line2) = LocationTimeStrip.splitAddress("Downtown")
        #expect(line1 == "DOWNTOWN")
        #expect(line2 == "")
    }

    @Test func splitAddressHandlesEmpty() {
        let (line1, line2) = LocationTimeStrip.splitAddress(nil)
        #expect(line1 == "")
        #expect(line2 == "")
    }

    @MainActor @Test func viewInstantiatesWithLocation() {
        _ = LocationTimeStrip(
            location: LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 Treat Ave, San Francisco"),
            createdAt: sampleDate,
            timeOfDay: .sunset
        ).body
    }

    @MainActor @Test func viewInstantiatesWithoutLocation() {
        _ = LocationTimeStrip(location: nil, createdAt: sampleDate, timeOfDay: .midday).body
    }
}
