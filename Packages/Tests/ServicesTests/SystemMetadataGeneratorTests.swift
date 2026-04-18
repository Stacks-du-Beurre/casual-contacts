import Testing
import Foundation
import CoreModels
@testable import Services

@Suite struct SystemMetadataGeneratorTests {

    private func isoDate(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)!
    }

    @Test func metadataIncludesTimeOfDayAndMoonPhase() {
        let generator = SystemMetadataGenerator(timeZoneProvider: { "UTC" })
        let fullMoon = isoDate("2024-01-25T18:00:00Z")

        let metadata = generator.metadata(at: fullMoon, location: nil)

        #expect(metadata.moonPhase == .fullMoon)
        #expect(metadata.timeOfDay == .sunset)
    }

    @Test func metadataUsesLocationTimezoneWhenAvailable() {
        let generator = SystemMetadataGenerator(timeZoneProvider: { "Asia/Tokyo" })
        let fullMoon = isoDate("2024-01-25T18:00:00Z")

        let metadata = generator.metadata(
            at: fullMoon,
            location: LocationInfo(latitude: 35.68, longitude: 139.77, label: "Tokyo")
        )

        #expect(metadata.timeOfDay == .midnight)
        #expect(metadata.moonPhase == .fullMoon)
    }
}
