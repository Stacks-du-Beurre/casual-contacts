import Foundation

public struct RecordMetadata: Hashable, Codable, Sendable {
    public let timeOfDay: TimeOfDay
    public let moonPhase: MoonPhase

    public init(timeOfDay: TimeOfDay, moonPhase: MoonPhase) {
        self.timeOfDay = timeOfDay
        self.moonPhase = moonPhase
    }
}
