import Foundation

public enum MoonPhase: String, CaseIterable, Codable, Sendable {
    case newMoon, waxingCrescent, firstQuarter, waxingGibbous
    case fullMoon, waningGibbous, thirdQuarter, waningCrescent
}
