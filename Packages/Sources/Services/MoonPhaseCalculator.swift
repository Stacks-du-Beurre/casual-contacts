import Foundation
import CoreModels

public enum MoonPhaseCalculator {

    /// Synodic month length in days (moon cycle from new to new).
    private static let synodicMonth = 29.530_588_67

    /// Julian day of a known new moon: 2000-01-06 18:14 UTC.
    private static let knownNewMoonJD = 2_451_550.1

    public static func phase(at date: Date) -> MoonPhase {
        let jd = julianDay(from: date)
        let cycles = (jd - knownNewMoonJD) / synodicMonth
        var fraction = cycles - cycles.rounded(.down)
        if fraction < 0 { fraction += 1 }

        switch fraction {
        case 0.0..<0.0625, 0.9375...1.0:
            return .newMoon
        case 0.0625..<0.1875:
            return .waxingCrescent
        case 0.1875..<0.3125:
            return .firstQuarter
        case 0.3125..<0.4375:
            return .waxingGibbous
        case 0.4375..<0.5625:
            return .fullMoon
        case 0.5625..<0.6875:
            return .waningGibbous
        case 0.6875..<0.8125:
            return .thirdQuarter
        case 0.8125..<0.9375:
            return .waningCrescent
        default:
            return .newMoon
        }
    }

    private static func julianDay(from date: Date) -> Double {
        // 2440587.5 = JD of 1970-01-01T00:00:00Z
        return 2_440_587.5 + date.timeIntervalSince1970 / 86_400.0
    }
}
