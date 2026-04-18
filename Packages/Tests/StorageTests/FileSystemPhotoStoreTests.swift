import Testing
import Foundation
import CoreModels
@testable import Storage

@Suite struct FileSystemPhotoStoreTests {

    private func makeStore() throws -> (store: FileSystemPhotoStore, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-photos-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (FileSystemPhotoStore(rootURL: root), root)
    }

    @Test func saveWritesDataAndReturnsPhotoID() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let photoID = try await store.save(Data([0x1, 0x2, 0x3]))

        let fileURL = root.appendingPathComponent(photoID.filename)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func loadReturnsWrittenData() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let input = Data("hello".utf8)
        let photoID = try await store.save(input)

        let loaded = try await store.load(photoID)
        #expect(loaded == input)
    }

    @Test func loadReturnsNilForMissingID() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let missing = PhotoID(filename: "does-not-exist.heic")
        let result = try await store.load(missing)

        #expect(result == nil)
    }

    @Test func deleteRemovesFile() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let photoID = try await store.save(Data("hello".utf8))
        try await store.delete(photoID)

        let fileURL = root.appendingPathComponent(photoID.filename)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func deleteThrowsForMissingID() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let missing = PhotoID(filename: "ghost.heic")
        await #expect(throws: PhotoStoreError.notFound(missing)) {
            try await store.delete(missing)
        }
    }
}
