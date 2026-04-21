import Foundation
import SwiftUI
import Observation
import CoreModels
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
public final class PhotoCache {

    public struct Entry: Sendable {
        public let image: Image
        /// Pixel dimensions of the source image, used by `PhotoLayer` to compute
        /// the offset that places a normalized focus point at container center.
        public let size: CGSize
    }

    private var cache: [String: Entry] = [:]
    private var inFlight: Set<String> = []

    public init() {}

    public func entry(for id: PhotoID?) -> Entry? {
        guard let id else { return nil }
        return cache[id.filename]
    }

    public func image(for id: PhotoID?) -> Image? {
        entry(for: id)?.image
    }

    public func imageSize(for id: PhotoID?) -> CGSize? {
        entry(for: id)?.size
    }

    public func load(_ id: PhotoID?, using store: any PhotoStore) async {
        guard let id, cache[id.filename] == nil, !inFlight.contains(id.filename) else { return }
        inFlight.insert(id.filename)
        defer { inFlight.remove(id.filename) }
        guard let data = try? await store.load(id), let entry = Self.decode(data) else { return }
        cache[id.filename] = entry
    }

    public func preload(_ records: [Record], using store: any PhotoStore) async {
        for record in records {
            await load(record.photoID, using: store)
        }
    }

    private static func decode(_ data: Data) -> Entry? {
        #if canImport(UIKit)
        guard let ui = UIImage(data: data) else { return nil }
        return Entry(image: Image(uiImage: ui), size: ui.size)
        #else
        return nil
        #endif
    }
}
