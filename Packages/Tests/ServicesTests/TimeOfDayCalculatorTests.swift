import Testing
import Foundation
import CoreModels
@testable import Services

@Suite struct TimeOfDayCalculatorTests {

    private func date(hour: Int, minute: Int = 0, timeZone: String = "UTC") -> Date {
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 15
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: timeZone)
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    @Test func midnightReturnsMidnight() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 2), timeZone: "UTC") == .midnight)
    }

    @Test func earlyMorningReturnsDawn() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 5), timeZone: "UTC") == .dawn)
    }

    @Test func morningReturnsSunrise() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 7), timeZone: "UTC") == .sunrise)
    }

    @Test func middayReturnsMidday() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 13), timeZone: "UTC") == .midday)
    }

    @Test func earlyEveningReturnsSunset() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 18), timeZone: "UTC") == .sunset)
    }

    @Test func duskAfterSunset() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 20), timeZone: "UTC") == .dusk)
    }

    @Test func lateEveningReturnsNight() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 22), timeZone: "UTC") == .night)
    }

    @Test func boundaryMidnightIsMidnight() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 0), timeZone: "UTC") == .midnight)
    }
}
