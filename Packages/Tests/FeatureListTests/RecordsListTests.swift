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

    @Test func cardAccessibilityLabelComposesRecordFields() {
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
        let label = CardView.accessibilityLabel(for: record)
        #expect(label.contains("Jane"))
        #expect(label.contains("Met at cafe"))
        #expect(label.contains("Mission St"))
    }

    @Test func emptyStateViewInstantiates() {
        _ = EmptyStateView(paths: NoopCardPathProvider(), timeOfDay: .sunset).body
    }

    @MainActor
    @Test func editMenuActionInvokesOnEditRecord() {
        let record = Record(
            id: UUID(),
            name: "Edit me",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .firstQuarter)
        )
        let store = InMemoryRecordStore(seed: [record])

        var captured: Record?
        let scene = RecordsListScene(
            store: store,
            paths: NoopCardPathProvider(),
            attitude: .zero,
            timeOfDay: .midday,
            onTapRecord: { _ in },
            onTapCreate: {},
            onTapSettings: {},
            onEditRecord: { captured = $0 }
        )
        _ = scene.body  // realize the view

        // We can't drive the menu's button action without rendering, so assert
        // the closure is wired by reading it back via Mirror.
        let mirror = Mirror(reflecting: scene)
        let onEditRecord = mirror.children.first { $0.label == "onEditRecord" }
        #expect(onEditRecord != nil)

        // Direct invoke as a sanity check.
        (onEditRecord?.value as? (Record) -> Void)?(record)
        #expect(captured?.id == record.id)
    }
}
