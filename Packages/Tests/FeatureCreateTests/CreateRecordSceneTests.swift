import Testing
import SwiftUI
import Foundation
import CoreModels
import Visuals
@testable import FeatureCreate

@MainActor
@Suite struct CreateRecordSceneTests {

    private struct StubPaths: CardPathProvider {
        func rotationPaths(for letter: Character) -> [Path] { [] }
        func blendPaths(for letter: Character, shape: GuillocheShape, density: CCVisuals.Guilloche.LineDensity) -> [Path] { [] }
    }

    private let fixedDate = Date(timeIntervalSince1970: 1_598_376_000)
    private let metadata = RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
    private let location = LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 Treat Ave, San Francisco")

    @Test func sceneInstantiatesWithAllInputs() {
        _ = CreateRecordScene(
            attitude: .zero,
            paths: StubPaths(),
            createdAt: fixedDate,
            metadata: metadata,
            location: location,
            onCancel: {},
            onSave: { _ in }
        ).body
    }

    @Test func sceneInstantiatesWithoutLocation() {
        _ = CreateRecordScene(
            attitude: .zero,
            paths: StubPaths(),
            createdAt: fixedDate,
            metadata: metadata,
            location: nil,
            onCancel: {},
            onSave: { _ in }
        ).body
    }
}
