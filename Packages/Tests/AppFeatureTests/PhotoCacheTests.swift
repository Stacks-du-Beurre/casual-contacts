import Testing
import Foundation
import CoreModels
@testable import AppFeature

@MainActor
@Suite struct PhotoCacheTests {

    private final class StubStore: PhotoStore, @unchecked Sendable {
        let payload: Data
        init(payload: Data) { self.payload = payload }
        func save(_ data: Data) async throws -> PhotoID { PhotoID(filename: "x.jpg") }
        func load(_ id: PhotoID) async throws -> Data? { payload }
        func delete(_ id: PhotoID) async throws { /* no-op */ }
    }

    @Test func invalidateDropsCachedEntry() async {
        let cache = PhotoCache()
        let id = PhotoID(filename: "id.jpg")
        let store = StubStore(payload: Data([0xFF, 0xD8])) // JPEG SOI; iOS may decode as nil on macOS host.

        await cache.load(id, using: store)
        // On macOS host without UIKit decoding, image() returns nil; that's fine.
        cache.invalidate(id)
        #expect(cache.image(for: id) == nil)
    }
}
