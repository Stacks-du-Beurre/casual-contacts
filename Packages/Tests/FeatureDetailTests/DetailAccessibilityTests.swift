import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import FeatureDetail

@Suite @MainActor struct DetailAccessibilityTests {

    private func makeRecord(
        name: String = "Jane",
        description: String = "Met at cafe",
        locationLabel: String? = "Mission St"
    ) -> Record {
        Record(
            id: UUID(),
            name: name,
            description: description,
            photoID: nil,
            location: locationLabel.map { LocationInfo(latitude: 0, longitude: 0, label: $0) },
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)
        )
    }

    @Test func mediumDetailLabelComposesRecordFields() {
        let label = MediumDetailSheet.accessibilityLabel(for: makeRecord())
        #expect(label.contains("Jane"))
        #expect(label.contains("Met at cafe"))
        #expect(label.contains("Mission St"))
    }

    @Test func largeDetailLabelComposesRecordFields() {
        let label = LargeDetailScene.accessibilityLabel(for: makeRecord())
        #expect(label.contains("Jane"))
        #expect(label.contains("Met at cafe"))
        #expect(label.contains("Mission St"))
    }
}
