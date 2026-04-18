import Foundation
import CoreModels

public final class FileSystemPhotoStore: PhotoStore, @unchecked Sendable {

    private let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    public func save(_ data: Data) async throws -> PhotoID {
        let filename = "\(UUID().uuidString).heic"
        let url = rootURL.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return PhotoID(filename: filename)
        } catch {
            throw PhotoStoreError.writeFailed(reason: String(describing: error))
        }
    }

    public func load(_ id: PhotoID) async throws -> Data? {
        let url = rootURL.appendingPathComponent(id.filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    public func delete(_ id: PhotoID) async throws {
        let url = rootURL.appendingPathComponent(id.filename)
        guard fileManager.fileExists(atPath: url.path) else {
            throw PhotoStoreError.notFound(id)
        }
        try fileManager.removeItem(at: url)
    }
}
