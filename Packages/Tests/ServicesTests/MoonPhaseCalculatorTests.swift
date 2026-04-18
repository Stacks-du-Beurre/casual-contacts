import Testing
import Foundation
import CoreModels
@testable import Services

@Suite struct MoonPhaseCalculatorTests {

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)!
    }

    @Test func newMoonJanuary2024() {
        let phase = MoonPhaseCalculator.phase(at: date("2024-01-11T12:00:00Z"))
        #expect(phase == .newMoon)
    }

    @Test func fullMoonJanuary2024() {
        let phase = MoonPhaseCalculator.phase(at: date("2024-01-25T12:00:00Z"))
        #expect(phase == .fullMoon)
    }

    @Test func firstQuarterJanuary2024() {
        let phase = MoonPhaseCalculator.phase(at: date("2024-01-18T03:53:00Z"))
        #expect(phase == .firstQuarter)
    }

    @Test func lastQuarterFebruary2024() {
        let phase = MoonPhaseCalculator.phase(at: date("2024-02-02T23:18:00Z"))
        #expect(phase == .thirdQuarter)
    }

    @Test func phaseIsOneOfEightKnownCases() {
        let phase = MoonPhaseCalculator.phase(at: Date())
        #expect(MoonPhase.allCases.contains(phase))
    }
}
