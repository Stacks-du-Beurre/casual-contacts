import Foundation

public enum TimeOfDay: String, CaseIterable, Codable, Sendable {
    case dawn, sunrise, midday, sunset, dusk, night, midnight
}
