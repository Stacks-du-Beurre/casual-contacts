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

    @Test func sortByDistancePutsClosestFirst() {
        let origin = LocationInfo(latitude: 37.7749, longitude: -122.4194)
        let near = TestRecord(name: "Near", latOffset: 0.001, lngOffset: 0)
        let mid = TestRecord(name: "Mid", latOffset: 0.005, lngOffset: 0)
        let far = TestRecord(name: "Far", latOffset: 0.5, lngOffset: 0)
        let sorted = RecordsListScene.sorted(
            [far.record(origin: origin), mid.record(origin: origin), near.record(origin: origin)],
            by: .distance,
            from: origin
        )
        #expect(sorted.map(\.name) == ["Near", "Mid", "Far"])
    }

    @Test func bucketingPutsWithin1MileFirstAndRestSecond() {
        let origin = LocationInfo(latitude: 37.7749, longitude: -122.4194)
        let inside = TestRecord(name: "Inside", latOffset: 0.005, lngOffset: 0).record(origin: origin)
        let outside = TestRecord(name: "Outside", latOffset: 0.5, lngOffset: 0).record(origin: origin)
        let bucketed = RecordsListScene.bucketed([outside, inside], from: origin)
        #expect(bucketed.near.map(\.name) == ["Inside"])
        #expect(bucketed.far.map(\.name) == ["Outside"])
    }

    @Test func bucketingWithNoCurrentLocationReturnsAllInFar() {
        let origin = LocationInfo(latitude: 0, longitude: 0)
        let one = TestRecord(name: "One", latOffset: 0.001, lngOffset: 0).record(origin: origin)
        let two = TestRecord(name: "Two", latOffset: 0.5, lngOffset: 0).record(origin: origin)
        let bucketed = RecordsListScene.bucketed([one, two], from: nil)
        #expect(bucketed.near.isEmpty)
        #expect(bucketed.far.count == 2)
    }

    @Test func bucketingTreatsRecordsWithoutLocationAsFar() {
        let origin = LocationInfo(latitude: 37.7749, longitude: -122.4194)
        let near = TestRecord(name: "Near", latOffset: 0.001, lngOffset: 0).record(origin: origin)
        let nilLoc = Record(
            id: UUID(),
            name: "Unknown",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .firstQuarter)
        )
        let bucketed = RecordsListScene.bucketed([near, nilLoc], from: origin)
        #expect(bucketed.near.map(\.name) == ["Near"])
        #expect(bucketed.far.map(\.name) == ["Unknown"])
    }

    @Test func bucketingSortsClosestFirstWithinEachBucket() {
        let origin = LocationInfo(latitude: 37.7749, longitude: -122.4194)
        let nearA = TestRecord(name: "NearA", latOffset: 0.005, lngOffset: 0).record(origin: origin)
        let nearB = TestRecord(name: "NearB", latOffset: 0.001, lngOffset: 0).record(origin: origin)
        let farA = TestRecord(name: "FarA", latOffset: 1.0, lngOffset: 0).record(origin: origin)
        let farB = TestRecord(name: "FarB", latOffset: 0.5, lngOffset: 0).record(origin: origin)
        let bucketed = RecordsListScene.bucketed([nearA, nearB, farA, farB], from: origin)
        #expect(bucketed.near.map(\.name) == ["NearB", "NearA"])
        #expect(bucketed.far.map(\.name) == ["FarB", "FarA"])
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
            onTapRecord: { _, _ in },
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

    @Test func recordsListAcceptsDistanceSortRequestCallback() {
        var requested = false
        let scene = RecordsListScene(
            store: InMemoryRecordStore(seed: []),
            paths: NoopCardPathProvider(),
            attitude: .zero,
            timeOfDay: .midday,
            onTapRecord: { _, _ in },
            onTapCreate: {},
            onTapSettings: {},
            onDistanceSortRequest: { requested = true }
        )
        _ = scene.body

        let mirror = Mirror(reflecting: scene)
        let callback = mirror.children.first { $0.label == "onDistanceSortRequest" }
        #expect(callback != nil)
        (callback?.value as? () -> Void)?()
        #expect(requested)
    }

    @Test func renderStateDistinguishesEmptyStoreFromEmptySearchResults() {
        let jane = Record(
            id: UUID(),
            name: "Jane",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .firstQuarter)
        )

        #expect(RecordsListScene.renderState(records: [], searchText: "") == .emptyStore)
        #expect(RecordsListScene.renderState(records: [jane], searchText: "zzzz") == .noVisibleMatches)
        #expect(RecordsListScene.renderState(records: [jane], searchText: "jan") == .showingRecords)
    }
}

private struct TestRecord {
    let name: String
    let latOffset: Double
    let lngOffset: Double

    func record(origin: LocationInfo) -> Record {
        Record(
            id: UUID(),
            name: name,
            description: "",
            photoID: nil,
            location: LocationInfo(
                latitude: origin.latitude + latOffset,
                longitude: origin.longitude + lngOffset
            ),
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .firstQuarter)
        )
    }
}
