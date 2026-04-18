import Testing
import Foundation
import CoreModels
@testable import StorageTestSupport

@MainActor
@Suite struct InMemoryRecordStoreTests {

    private let sampleMetadata = RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)

    @Test func createAddsRecordAndReturnsIt() async throws {
        let store = InMemoryRecordStore()
        let record = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)

        #expect(record.name == "Jane")
        #expect(store.records.count == 1)
    }

    @Test func createdRecordsAreSortedNewestFirst() async throws {
        let store = InMemoryRecordStore()
        _ = try await store.create(RecordDraft(name: "A"), metadata: sampleMetadata)
        try await Task.sleep(nanoseconds: 1_000_000)
        _ = try await store.create(RecordDraft(name: "B"), metadata: sampleMetadata)

        #expect(store.records.map(\.name) == ["B", "A"])
    }

    @Test func deleteRemovesRecord() async throws {
        let store = InMemoryRecordStore()
        let record = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)

        try await store.delete(id: record.id)

        #expect(store.records.isEmpty)
    }

    @Test func updateThrowsForMissingRecord() async throws {
        let store = InMemoryRecordStore()
        let ghost = Record(
            id: UUID(),
            name: "Ghost",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)
        )

        await #expect(throws: RecordStoreError.notFound(ghost.id)) {
            try await store.update(ghost)
        }
    }

    @Test func searchIsCaseInsensitive() async throws {
        let store = InMemoryRecordStore()
        _ = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)
        _ = try await store.create(RecordDraft(name: "John"), metadata: sampleMetadata)

        #expect(store.search("ja").map(\.name) == ["Jane"])
    }

    @Test func preloadedRecordsAreAvailable() async throws {
        let seed = Record(
            id: UUID(),
            name: "Preloaded",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)
        )
        let store = InMemoryRecordStore(seed: [seed])

        #expect(store.records.count == 1)
        #expect(store.records.first?.name == "Preloaded")
    }
}
