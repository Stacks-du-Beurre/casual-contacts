import Testing
import Foundation
import CoreModels
@testable import StorageTestSupport

@Suite struct InMemoryPhotoStoreTests {

    @Test func saveAndLoadReturnsData() async throws {
        let store = InMemoryPhotoStore()
        let input = Data("abc".utf8)

        let id = try await store.save(input)
        let loaded = try await store.load(id)

        #expect(loaded == input)
    }

    @Test func loadReturnsNilForMissingID() async throws {
        let store = InMemoryPhotoStore()
        let missing = PhotoID(filename: "ghost.heic")
        let loaded = try await store.load(missing)
        #expect(loaded == nil)
    }

    @Test func deleteRemovesData() async throws {
        let store = InMemoryPhotoStore()
        let id = try await store.save(Data("abc".utf8))

        try await store.delete(id)

        let loaded = try await store.load(id)
        #expect(loaded == nil)
    }

    @Test func deleteThrowsForMissingID() async throws {
        let store = InMemoryPhotoStore()
        let ghost = PhotoID(filename: "ghost.heic")
        await #expect(throws: PhotoStoreError.notFound(ghost)) {
            try await store.delete(ghost)
        }
    }
}
