import Foundation

public protocol RecordStore: AnyObject, Sendable {
    @MainActor var records: [Record] { get }
    func create(_ draft: RecordDraft, metadata: RecordMetadata, photoID: PhotoID?) async throws -> Record
    func update(_ record: Record) async throws
    func delete(id: Record.ID) async throws
    @MainActor func search(_ query: String) -> [Record]
}

public extension RecordStore {
    func create(_ draft: RecordDraft, metadata: RecordMetadata) async throws -> Record {
        try await create(draft, metadata: metadata, photoID: nil)
    }
}

public enum RecordStoreError: Error, Sendable, Equatable {
    case notFound(Record.ID)
    case saveFailed(reason: String)
}
