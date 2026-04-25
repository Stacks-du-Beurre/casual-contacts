import Foundation

public protocol RecordStore: AnyObject, Sendable {
    @MainActor var records: [Record] { get }
    func create(_ draft: RecordDraft, metadata: RecordMetadata, photoID: PhotoID?) async throws -> Record
    /// Insert a fully-formed `Record` (with caller-assigned `id`, timestamps,
    /// metadata, etc.). Skips the draft → record promotion that `create(_:)`
    /// performs. Used for fixture/debug seeding where stable IDs and
    /// hand-crafted metadata matter; production flows should use `create(_:)`.
    func insert(_ record: Record) async throws
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
