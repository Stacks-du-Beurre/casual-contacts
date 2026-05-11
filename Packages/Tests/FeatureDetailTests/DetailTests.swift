import Testing
import SwiftUI
import Foundation
import CoreModels
import Visuals
@testable import FeatureDetail

struct NoopCardPathProvider: CardPathProvider {
    func rotationPaths(for letter: Character) -> [Path] { [] }
    func blendPaths(for letter: Character, shape: GuillocheShape, density: CCVisuals.Guilloche.LineDensity) -> [Path] { [] }
}

@MainActor
@Suite struct DetailTests {

    private func sampleRecord() -> Record {
        Record(
            id: UUID(),
            name: "Jane",
            description: "Met at the coffee shop",
            photoID: nil,
            location: LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 TREAT AVE"),
            zodiacSign: .virgo,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
        )
    }

    @Test func mediumDetailSheetInstantiates() {
        _ = MediumDetailSheet(
            record: sampleRecord(),
            attitude: .zero,
            paths: NoopCardPathProvider(),
            onExpand: {},
            onEdit: {},
            onDelete: {},
            onDismiss: {}
        ).body
    }

    @Test func largeDetailSceneInstantiates() {
        _ = LargeDetailScene(
            record: sampleRecord(),
            attitude: .zero,
            paths: NoopCardPathProvider(),
            onEdit: {},
            onDelete: {},
            onDismiss: {}
        ).body
    }

    @Test func detailEditFormInstantiates() {
        _ = DetailEditForm(
            record: sampleRecord(),
            onCancel: {},
            onSave: { _ in }
        ).body
    }

    @Test func locationLabelUsesProvidedLocale() {
        #expect(
            DetailEditForm.locationLabel("1200 TREAT AVE", locale: Locale(identifier: "uk"))
                == "Місце: 1200 TREAT AVE"
        )
        #expect(
            DetailEditForm.locationLabel("1200 TREAT AVE", locale: Locale(identifier: "ru"))
                == "Место: 1200 TREAT AVE"
        )
    }
}
