import Testing
import SwiftUI
import Foundation
import CoreModels
import Visuals
import StorageTestSupport
@testable import FeatureList

struct NoopCardPathProvider: CardPathProvider {
    func rotationPaths(for letter: Character) -> [Path] { [] }
    func blendPaths(for letter: Character, shape: GuillocheShape, density: CCVisuals.Guilloche.LineDensity) -> [Path] { [] }
}

@MainActor
@Suite struct RecordsListTests {

    @Test func smallCardAccessibilityLabelComposesRecordFields() {
        let record = Record(
            id: UUID(),
            name: "Jane",
            description: "Met at cafe",
            photoID: nil,
            location: LocationInfo(latitude: 0, longitude: 0, label: "Mission St"),
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)
        )
        let label = SmallCardListItem.accessibilityLabel(for: record)
        #expect(label.contains("Jane"))
        #expect(label.contains("Met at cafe"))
        #expect(label.contains("Mission St"))
    }

    @Test func emptyStateViewInstantiates() {
        _ = EmptyStateView(paths: NoopCardPathProvider()).body
    }
}
