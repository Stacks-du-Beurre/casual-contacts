import Testing
import Foundation
import SwiftData
import CoreModels
@testable import Storage

@MainActor
@Suite struct SwiftDataRecordStoreTests {

    private func makeStore() throws -> SwiftDataRecordStore {
        let container = try ModelContainer(
            for: PersistedRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SwiftDataRecordStore(container: container)
    }

    private let sampleMetadata = RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)

    @Test func createReturnsRecordWithGeneratedIDAndTimestamps() async throws {
        let store = try makeStore()
        let draft = RecordDraft(name: "Jane", description: "Met at the coffee shop")

        let record = try await store.create(draft, metadata: sampleMetadata)

        #expect(record.name == "Jane")
        #expect(record.description == "Met at the coffee shop")
        #expect(record.createdAt == record.updatedAt)
        #expect(record.metadata == sampleMetadata)
    }

    @Test func createdRecordAppearsInRecords() async throws {
        let store = try makeStore()
        _ = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)

        #expect(store.records.count == 1)
        #expect(store.records.first?.name == "Jane")
    }

    @Test func roundTripPreservesAllFields() async throws {
        let store = try makeStore()
        let draft = RecordDraft(
            name: "Jane",
            description: "Met at the coffee shop",
            location: LocationInfo(latitude: 37.77, longitude: -122.41, label: "SF"),
            zodiacSign: .virgo
        )

        let created = try await store.create(draft, metadata: sampleMetadata)

        let fetched = store.records.first { $0.id == created.id }
        #expect(fetched == created)
    }

    @Test func updateModifiesExistingRecord() async throws {
        let store = try makeStore()
        var record = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)

        record.name = "Janet"
        record.zodiacSign = .virgo
        try await store.update(record)

        let fetched = store.records.first { $0.id == record.id }
        #expect(fetched?.name == "Janet")
        #expect(fetched?.zodiacSign == .virgo)
    }

    @Test func deleteRemovesRecord() async throws {
        let store = try makeStore()
        let record = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)

        try await store.delete(id: record.id)

        #expect(store.records.isEmpty)
    }

    @Test func updateThrowsForMissingRecord() async throws {
        let store = try makeStore()
        let missing = Record(
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

        await #expect(throws: RecordStoreError.notFound(missing.id)) {
            try await store.update(missing)
        }
    }

    @Test func searchWithEmptyQueryReturnsAllRecords() async throws {
        let store = try makeStore()
        _ = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)
        _ = try await store.create(RecordDraft(name: "John"), metadata: sampleMetadata)

        let results = store.search("")

        #expect(results.count == 2)
    }

    @Test func searchFiltersByNameCaseInsensitive() async throws {
        let store = try makeStore()
        _ = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)
        _ = try await store.create(RecordDraft(name: "John"), metadata: sampleMetadata)
        _ = try await store.create(RecordDraft(name: "Janet"), metadata: sampleMetadata)

        let results = store.search("jan")

        #expect(results.count == 2)
        #expect(Set(results.map(\.name)) == ["Jane", "Janet"])
    }

    @Test func searchTrimsWhitespace() async throws {
        let store = try makeStore()
        _ = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)

        let results = store.search("   Jane   ")

        #expect(results.count == 1)
    }
}
