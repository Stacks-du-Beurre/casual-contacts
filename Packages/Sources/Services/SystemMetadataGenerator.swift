import Foundation
import CoreModels

public struct SystemMetadataGenerator: MetadataGenerator {

    private let timeZoneProvider: @Sendable () -> String

    public init(timeZoneProvider: @escaping @Sendable () -> String = { TimeZone.current.identifier }) {
        self.timeZoneProvider = timeZoneProvider
    }

    public func metadata(at date: Date, location: LocationInfo?) -> RecordMetadata {
        let timeZone = timeZoneProvider()
        return RecordMetadata(
            timeOfDay: TimeOfDayCalculator.category(at: date, timeZone: timeZone),
            moonPhase: MoonPhaseCalculator.phase(at: date)
        )
    }
}
