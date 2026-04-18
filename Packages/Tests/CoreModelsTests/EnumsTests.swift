import Foundation
import Testing
import CoreModels

@Suite struct EnumsTests {

    @Test func timeOfDayHasSevenCases() {
        #expect(TimeOfDay.allCases.count == 7)
        #expect(TimeOfDay.allCases.contains(.dawn))
        #expect(TimeOfDay.allCases.contains(.midnight))
    }

    @Test func moonPhaseHasEightCases() {
        #expect(MoonPhase.allCases.count == 8)
        #expect(MoonPhase.allCases.contains(.newMoon))
        #expect(MoonPhase.allCases.contains(.waningCrescent))
    }

    @Test func zodiacHasTwelveCases() {
        #expect(ZodiacSign.allCases.count == 12)
        #expect(ZodiacSign.allCases.contains(.aries))
        #expect(ZodiacSign.allCases.contains(.pisces))
    }

    @Test func guillocheShapeHasThreeCases() {
        #expect(GuillocheShape.allCases.count == 3)
    }

    @Test func timeOfDayRawValuesStable() throws {
        let encoded = try JSONEncoder().encode(TimeOfDay.sunset)
        #expect(String(data: encoded, encoding: .utf8) == "\"sunset\"")
    }

    @Test func moonPhaseRoundTripsThroughJSON() throws {
        let original = MoonPhase.waxingGibbous
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MoonPhase.self, from: data)
        #expect(decoded == original)
    }
}
