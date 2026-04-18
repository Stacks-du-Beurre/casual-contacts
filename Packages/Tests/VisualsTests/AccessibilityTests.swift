import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import Visuals

@Suite @MainActor struct AccessibilityTests {

    private func makeRecord(
        name: String = "Jane",
        description: String = "Met at cafe",
        locationLabel: String? = "Mission St",
        moonPhase: MoonPhase = .fullMoon,
        timeOfDay: TimeOfDay = .midday,
        zodiac: ZodiacSign? = .virgo
    ) -> Record {
        Record(
            id: UUID(),
            name: name,
            description: description,
            photoID: nil,
            location: locationLabel.map { LocationInfo(latitude: 0, longitude: 0, label: $0) },
            zodiacSign: zodiac,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            metadata: RecordMetadata(timeOfDay: timeOfDay, moonPhase: moonPhase)
        )
    }

    @Test func cardAccessibilityLabelIncludesAllPublicFields() {
        let record = makeRecord()
        let label = CardView.accessibilityLabel(for: record)
        #expect(label.contains("Jane"))
        #expect(label.contains("Met at cafe"))
        #expect(label.contains("Mission St"))
    }

    @Test func cardAccessibilityLabelOmitsEmptyDescription() {
        let record = makeRecord(description: "", locationLabel: nil)
        let label = CardView.accessibilityLabel(for: record)
        #expect(label == "Jane")
    }

    @Test func cardAccessibilityLabelOmitsNilLocation() {
        let record = makeRecord(description: "Met at cafe", locationLabel: nil)
        let label = CardView.accessibilityLabel(for: record)
        #expect(label == "Jane. Met at cafe")
    }
}
