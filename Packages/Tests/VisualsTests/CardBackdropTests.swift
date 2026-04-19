import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import Visuals

@MainActor
@Suite struct CardBackdropTests {

    private struct StubPaths: CardPathProvider {
        func rotationPaths(for letter: Character) -> [Path] { [] }
        func blendPaths(for letter: Character, shape: GuillocheShape, density: CCVisuals.Guilloche.LineDensity) -> [Path] { [] }
    }

    private func record() -> Record {
        Record(
            id: UUID(),
            name: "Jane",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: .virgo,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)
        )
    }

    @Test func backdropInstantiatesWithoutPhoto() {
        _ = CardBackdrop(
            record: record(),
            attitude: .zero,
            paths: StubPaths(),
            photo: nil
        ).body
    }

    @Test func backdropInstantiatesWithPhoto() {
        _ = CardBackdrop(
            record: record(),
            attitude: .zero,
            paths: StubPaths(),
            photo: Image(systemName: "photo")
        ).body
    }
}
