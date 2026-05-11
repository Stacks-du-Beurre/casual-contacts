import Testing
import SwiftUI
import CoreModels
import StorageTestSupport
@testable import AppFeature

@MainActor
@Suite struct RootSceneTests {

    @Test func initBuildsWithTestingEnvironment() {
        let env = AppEnvironment.testing()
        let scene = RootScene(environment: env)
        // Smoke test: instantiation alone proves the types compose. We can't
        // meaningfully host a `Scene` in unit tests without XCUITest.
        _ = scene
    }

    @Test func selectedLocaleUsesLanguagePreferenceIdentifier() {
        #expect(RootScene.locale(for: .system) == nil)
        #expect(RootScene.locale(for: .english)?.identifier == "en")
        #expect(RootScene.locale(for: .russian)?.identifier == "ru")
        #expect(RootScene.locale(for: .ukrainian)?.identifier == "uk")
    }

    @Test func navigationRouterDefaultsAreAllClear() {
        let router = NavigationRouter()
        #expect(router.showingCreate == false)
        #expect(router.showingSettings == false)
        #expect(router.showingAbout == false)
        #expect(router.showingInListDeveloperSettings == false)
        #expect(router.locationPrimerContext == nil)
        #expect(router.selectedRecordForMediumDetail == nil)
        #expect(router.selectedRecordForLargeDetail == nil)
        #expect(router.editingRecord == nil)
    }

    @Test func navigationRouterStoresRecordSelection() {
        let router = NavigationRouter()
        let record = Record(
            id: UUID(),
            name: "Jane",
            description: "Met at cafe",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .newMoon)
        )
        router.selectedRecordForMediumDetail = record
        #expect(router.selectedRecordForMediumDetail?.id == record.id)
    }

    @Test func navigationRouterClearsSelectionsForDeletedRecords() {
        let router = NavigationRouter()
        let kept = Record(
            id: UUID(),
            name: "Kept",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .newMoon)
        )
        let deleted = Record(
            id: UUID(),
            name: "Deleted",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .newMoon)
        )

        router.selectedRecordForMediumDetail = deleted
        router.selectedRecordForLargeDetail = kept
        router.tappedRecord = deleted
        router.editingRecord = deleted

        router.clearSelections(keeping: [kept.id])

        #expect(router.selectedRecordForMediumDetail == nil)
        #expect(router.selectedRecordForLargeDetail?.id == kept.id)
        #expect(router.tappedRecord == nil)
        #expect(router.editingRecord == nil)
    }

    // Smoke-checks that `RecordStore.update` round-trips a name change.
    // The `EditingSheetContent` save closure is not directly exercised by host
    // tests; full coverage lives in the simulator XCUITest suite (T13).
    @Test func recordStoreUpdateRoundTripsName() async throws {
        let original = Record(
            id: UUID(),
            name: "Old",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .firstQuarter)
        )
        let store = InMemoryRecordStore(seed: [original])
        let env = AppEnvironment.testing(recordStore: store)

        // Simulate the edit-flow save closure directly.
        let updated = Record(
            id: original.id,
            name: "New",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: original.createdAt,
            updatedAt: Date(),
            metadata: original.metadata,
            guillocheShape: original.guillocheShape
        )
        try await env.recordStore.update(updated)
        #expect(env.recordStore.records.first(where: { $0.id == original.id })?.name == "New")
    }

    // Smoke-checks that `TrackingPhotoStore` records `delete` invocations correctly.
    // The `EditingSheetContent` save closure is not directly exercised by host
    // tests; full coverage lives in the simulator XCUITest suite (T13).
    @Test func photoStoreDeleteRecordsInvocations() async throws {
        final class TrackingPhotoStore: PhotoStore, @unchecked Sendable {
            var deleted: [PhotoID] = []
            func save(_ data: Data) async throws -> PhotoID { PhotoID(filename: "new.jpg") }
            func load(_ id: PhotoID) async throws -> Data? { Data() }
            func delete(_ id: PhotoID) async throws { deleted.append(id) }
        }

        let photoStore = TrackingPhotoStore()
        let oldID = PhotoID(filename: "old.jpg")

        // Mirror the helper that RootScene's edit save closure will call.
        let newID = try await photoStore.save(Data([0x01]))
        try await photoStore.delete(oldID)

        #expect(newID.filename == "new.jpg")
        #expect(photoStore.deleted == [oldID])
    }
}
