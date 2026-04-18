import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import Visuals

struct StubCardPathProvider: CardPathProvider {
    func rotationPaths(for letter: Character) -> [Path] { [] }
    func blendPaths(for letter: Character, shape: GuillocheShape, density: CCVisuals.Guilloche.LineDensity) -> [Path] { [] }
}

@Suite struct CardViewTests {

    private func sampleRecord(zodiac: ZodiacSign? = nil) -> Record {
        Record(
            id: UUID(),
            name: "Jane",
            description: "Met at the coffee shop",
            photoID: nil,
            location: LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 TREAT AVE"),
            zodiacSign: zodiac,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
        )
    }

    @Test @MainActor func cardInstantiatesAtAllSizes() {
        let record = sampleRecord(zodiac: .virgo)
        let provider = StubCardPathProvider()
        _ = CardView(record: record, size: .small, attitude: .zero, paths: provider).body
        _ = CardView(record: record, size: .medium, attitude: .zero, paths: provider).body
        _ = CardView(record: record, size: .large, attitude: .zero, paths: provider).body
    }

    @Test @MainActor func cardInstantiatesWithoutZodiac() {
        let record = sampleRecord(zodiac: nil)
        _ = CardView(record: record, size: .medium, attitude: .zero, paths: StubCardPathProvider()).body
    }

    @Test @MainActor func cardInstantiatesWithPhoto() {
        let record = sampleRecord()
        _ = CardView(
            record: record,
            size: .medium,
            attitude: .zero,
            paths: StubCardPathProvider(),
            photo: Image(systemName: "photo")
        ).body
    }
}
