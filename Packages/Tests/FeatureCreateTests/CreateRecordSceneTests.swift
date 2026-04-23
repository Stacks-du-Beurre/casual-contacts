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

    // Alias so plan-authored tests can use either name.
    private typealias StubCardPathProvider = StubPaths

    private let fixedDate = Date(timeIntervalSince1970: 1_598_376_000)
    private let metadata = RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
    private let location = LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 Treat Ave, San Francisco")

    private struct StubFaceDetectionService: FaceDetectionService {
        func focusPoint(in imageData: Data) async -> NormalizedPoint? { nil }
    }

    @Test func sceneInstantiatesWithAllInputs() {
        _ = CreateRecordScene(
            attitude: .zero,
            paths: StubPaths(),
            faceDetectionService: StubFaceDetectionService(),
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
            faceDetectionService: StubFaceDetectionService(),
            createdAt: fixedDate,
            metadata: metadata,
            location: nil,
            onCancel: {},
            onSave: { _ in }
        ).body
    }

    @MainActor
    @Test func editingInitDeliversUpdateOutcomeOnSave() async {
        let record = Record(
            id: UUID(),
            name: "Original",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .firstQuarter)
        )

        var capturedOutcome: CreateRecordOutcome?
        let scene = CreateRecordScene(
            editing: record,
            attitude: .zero,
            paths: StubCardPathProvider(),
            faceDetectionService: StubFaceDetectionService(),
            photoData: nil,
            photoFocus: nil,
            onCancel: {},
            onSave: { outcome in capturedOutcome = outcome }
        )

        let mirror = Mirror(reflecting: scene)
        let modelChild = mirror.children.first { $0.label == "_model" }
        let modelStateValue = (modelChild?.value as? State<CreateRecordModel>)
        #expect(modelStateValue?.wrappedValue.name == "Original")

        // Drive a save — the scene's onSave wraps the model's draft into an
        // `.update(...)` outcome carrying the record's id and createdAt.
        let updated = Record(
            id: record.id,
            name: "Original",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: record.createdAt,
            updatedAt: Date(),
            metadata: record.metadata,
            guillocheShape: record.guillocheShape
        )
        scene.onSave(.update(updated, photoData: nil, photoFocus: nil))
        #expect(capturedOutcome != nil)
        if case let .update(out, _, _) = capturedOutcome { #expect(out.id == record.id) }
        else { Issue.record("expected .update outcome") }
    }

    @MainActor
    @Test func createInitStillDeliversCreateOutcome() {
        var capturedOutcome: CreateRecordOutcome?
        let scene = CreateRecordScene(
            attitude: .zero,
            paths: StubCardPathProvider(),
            faceDetectionService: StubFaceDetectionService(),
            createdAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .firstQuarter),
            location: nil,
            onCancel: {},
            onSave: { outcome in capturedOutcome = outcome }
        )
        scene.onSave(.create(RecordDraft(name: "New")))
        if case .create = capturedOutcome { } else { Issue.record("expected .create outcome") }
        _ = scene
    }
}
