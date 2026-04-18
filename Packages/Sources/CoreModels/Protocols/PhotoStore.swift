import Foundation

public protocol PhotoStore: Sendable {
    func save(_ data: Data) async throws -> PhotoID
    func load(_ id: PhotoID) async throws -> Data?
    func delete(_ id: PhotoID) async throws
}

public enum PhotoStoreError: Error, Sendable, Equatable {
    case writeFailed(reason: String)
    case notFound(PhotoID)
}
