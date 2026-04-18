import Foundation
import CoreModels

public actor InMemoryPhotoStore: PhotoStore {

    private var store: [PhotoID: Data] = [:]

    public init() {}

    public func save(_ data: Data) async throws -> PhotoID {
        let id = PhotoID(filename: "\(UUID().uuidString).heic")
        store[id] = data
        return id
    }

    public func load(_ id: PhotoID) async throws -> Data? {
        store[id]
    }

    public func delete(_ id: PhotoID) async throws {
        guard store.removeValue(forKey: id) != nil else {
            throw PhotoStoreError.notFound(id)
        }
    }
}
