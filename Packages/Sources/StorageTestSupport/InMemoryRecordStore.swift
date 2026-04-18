import Foundation
import CoreModels
import Observation

@MainActor
@Observable
public final class InMemoryRecordStore: RecordStore {

    public private(set) var records: [Record] = []

    public init(seed: [Record] = []) {
        self.records = seed.sorted { $0.createdAt > $1.createdAt }
    }

    public func create(_ draft: RecordDraft, metadata: RecordMetadata) async throws -> Record {
        let now = Date()
        let record = Record(
            id: UUID(),
            name: draft.name,
            description: draft.description,
            photoID: nil,
            location: draft.location,
            zodiacSign: draft.zodiacSign,
            createdAt: now,
            updatedAt: now,
            metadata: metadata
        )
        records.insert(record, at: 0)
        return record
    }

    public func update(_ record: Record) async throws {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else {
            throw RecordStoreError.notFound(record.id)
        }
        var updated = record
        updated.updatedAt = Date()
        records[index] = updated
    }

    public func delete(id: Record.ID) async throws {
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            throw RecordStoreError.notFound(id)
        }
        records.remove(at: index)
    }

    public func search(_ query: String) -> [Record] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return records }
        return records.filter { $0.name.lowercased().contains(trimmed) }
    }
}
