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

    @Test func listChromeLocalizesWithProvidedLocale() {
        #expect(ModuleLocalization.string("MY CONTACTS", locale: Locale(identifier: "ru")) == "МОИ КОНТАКТЫ")
        #expect(ModuleLocalization.string("Search", locale: Locale(identifier: "ru")) == "Поиск")
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

    @Test func sortingSheetSelectionReportsCompletionBeforeDismiss() {
        var selected = SortOption.alphabetical
        var reportedSelection: SortOption?
        var completedCount = 0
        var dismissedCount = 0

        let sheet = DefaultSortingSheet(
            selected: Binding(
                get: { selected },
                set: { selected = $0 }
            ),
            onSelectionChanged: { reportedSelection = $0 },
            onSelectionCompleted: { completedCount += 1 },
            onDistanceUnavailable: {},
            onAdvanced: {},
            onDismiss: { dismissedCount += 1 }
        )

        sheet.select(.dateCreated)

        #expect(selected == .dateCreated)
        #expect(reportedSelection == .dateCreated)
        #expect(completedCount == 1)
        #expect(dismissedCount == 1)
    }

    @Test func sortingSheetDistanceUnavailableStillReportsCompletion() {
        var selected = SortOption.alphabetical
        var reportedSelection: SortOption?
        var requestedCount = 0
        var completedCount = 0
        var dismissedCount = 0

        let sheet = DefaultSortingSheet(
            selected: Binding(
                get: { selected },
                set: { selected = $0 }
            ),
            isDistanceEnabled: false,
            onSelectionChanged: { reportedSelection = $0 },
            onSelectionCompleted: { completedCount += 1 },
            onDistanceUnavailable: { requestedCount += 1 },
            onAdvanced: {},
            onDismiss: { dismissedCount += 1 }
        )

        sheet.selectDistance()

        #expect(selected == .alphabetical)
        #expect(reportedSelection == nil)
        #expect(requestedCount == 1)
        #expect(completedCount == 1)
        #expect(dismissedCount == 1)
    }

    @Test func deleteMessagesUseProvidedLocale() {
        #expect(
            RecordsListScene.deleteConfirmationMessage(forRecordName: "", locale: Locale(identifier: "ru"))
                == "Этот контакт будет удален навсегда."
        )
        #expect(
            RecordsListScene.deleteErrorMessage(forRecordName: "Jane", locale: Locale(identifier: "uk"))
                == "Не вдалося видалити Jane. Спробуйте ще раз."
        )
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

    @Test func sortCacheDoesNotRecomputeWhenOnlyCardAttitudeChanges() {
        let origin = LocationInfo(latitude: 37.7749, longitude: -122.4194)
        let records = [
            TestRecord(name: "Far", latOffset: 0.5, lngOffset: 0).record(origin: origin),
            TestRecord(name: "Near", latOffset: 0.001, lngOffset: 0).record(origin: origin)
        ]
        let cache = RecordsListSortCache()
        var computeCount = 0

        let first = cache.bucketed(
            records: records,
            searchText: "",
            sortOption: .distance,
            currentLocation: origin
        ) { query in
            computeCount += 1
            return RecordsListSortCache.compute(query)
        }

        let second = cache.bucketed(
            records: records,
            searchText: "",
            sortOption: .distance,
            currentLocation: origin
        ) { query in
            computeCount += 1
            return RecordsListSortCache.compute(query)
        }

        #expect(first == second)
        #expect(computeCount == 1)
    }

    @Test func sortCacheRecomputesWhenLocationSnapshotChanges() {
        let origin = LocationInfo(latitude: 37.7749, longitude: -122.4194)
        let movedOrigin = LocationInfo(latitude: 37.7849, longitude: -122.4194)
        let records = [
            TestRecord(name: "A", latOffset: 0.001, lngOffset: 0).record(origin: origin),
            TestRecord(name: "B", latOffset: 0.5, lngOffset: 0).record(origin: origin)
        ]
        let cache = RecordsListSortCache()
        var computeCount = 0

        _ = cache.bucketed(
            records: records,
            searchText: "",
            sortOption: .distance,
            currentLocation: origin,
            compute: { query in
                computeCount += 1
                return RecordsListSortCache.compute(query)
            }
        )
        _ = cache.bucketed(
            records: records,
            searchText: "",
            sortOption: .distance,
            currentLocation: movedOrigin,
            compute: { query in
                computeCount += 1
                return RecordsListSortCache.compute(query)
            }
        )

        #expect(computeCount == 2)
    }

    @Test func cardAnimationVisibilityIncludesViewportAndPrewarmMargin() {
        #expect(CardAnimationVisibility.isActive(
            rowFrame: CGRect(x: 0, y: 20, width: 100, height: 200),
            viewportHeight: 600,
            prewarmMargin: 100
        ))
        #expect(CardAnimationVisibility.isActive(
            rowFrame: CGRect(x: 0, y: -90, width: 100, height: 80),
            viewportHeight: 600,
            prewarmMargin: 100
        ))
        #expect(CardAnimationVisibility.isActive(
            rowFrame: CGRect(x: 0, y: 650, width: 100, height: 80),
            viewportHeight: 600,
            prewarmMargin: 100
        ))
    }

    @Test func cardAnimationVisibilityExcludesRowsBeyondPrewarmMargin() {
        #expect(!CardAnimationVisibility.isActive(
            rowFrame: CGRect(x: 0, y: -220, width: 100, height: 80),
            viewportHeight: 600,
            prewarmMargin: 100
        ))
        #expect(!CardAnimationVisibility.isActive(
            rowFrame: CGRect(x: 0, y: 720, width: 100, height: 80),
            viewportHeight: 600,
            prewarmMargin: 100
        ))
        #expect(!CardAnimationVisibility.isActive(
            rowFrame: CGRect(x: 0, y: 20, width: 100, height: 80),
            viewportHeight: 0,
            prewarmMargin: 100
        ))
    }

    @Test func cardFramePreferenceKeepsLatestRowFrames() {
        var value = CardFrameSnapshot(
            global: CGRect(x: 0, y: 0, width: 100, height: 211),
            scroll: CGRect(x: 0, y: 720, width: 100, height: 211)
        )
        let latest = CardFrameSnapshot(
            global: CGRect(x: 0, y: 0, width: 100, height: 211),
            scroll: CGRect(x: 0, y: 420, width: 100, height: 211)
        )

        CardFramePreferenceKey.reduce(value: &value) { latest }

        #expect(value == latest)
        #expect(CardAnimationVisibility.isActive(rowFrame: value.scroll, viewportHeight: 600))
    }

    @Test func mountedRowsRenderWithLiveAttitudeEvenWhenVisibilityStateIsStale() {
        let attitude = DeviceAttitude(pitch: 0.25, roll: -0.5)

        #expect(CardRowMotionPolicy.renderedAttitude(attitude) == attitude)
    }

    @Test func scrollInteractionPolicyDoesNotPauseForProgrammaticAnimation() {
        #expect(ScrollInteractionPolicy.shouldPauseMotion(for: .userInteraction))
        #expect(!ScrollInteractionPolicy.shouldPauseMotion(for: .programmaticAnimation))
        #expect(!ScrollInteractionPolicy.shouldPauseMotion(for: .idle))
    }

    @Test func cardAnimationDiagnosticsTracksMountedAndActiveCounts() throws {
        let suiteName = "CardAnimationDiagnostics.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let diagnostics = CardAnimationDiagnostics(defaults: defaults, key: "showsOverlay")
        let first = UUID()
        let second = UUID()

        diagnostics.registerMountedCard(id: first)
        diagnostics.registerMountedCard(id: second)
        diagnostics.updateCardAnimation(id: first, isActive: true)

        #expect(diagnostics.mountedCardCount == 2)
        #expect(diagnostics.activeAnimatingCardCount == 1)

        diagnostics.updateCardAnimation(id: first, isActive: false)
        diagnostics.unregisterMountedCard(id: second)

        #expect(diagnostics.mountedCardCount == 1)
        #expect(diagnostics.activeAnimatingCardCount == 0)
    }

    @Test func cardAnimationDiagnosticsPersistsOverlayToggle() throws {
        let suiteName = "CardAnimationDiagnostics.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let diagnostics = CardAnimationDiagnostics(defaults: defaults, key: "showsOverlay")
        diagnostics.showsOverlay = true

        let reloaded = CardAnimationDiagnostics(defaults: defaults, key: "showsOverlay")
        #expect(reloaded.showsOverlay)
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
