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

    private var cache: [String: Image] = [:]
    private var inFlight: Set<String> = []

    public init() {}

    public func image(for id: PhotoID?) -> Image? {
        guard let id else { return nil }
        return cache[id.filename]
    }

    public func load(_ id: PhotoID?, using store: any PhotoStore) async {
        guard let id, cache[id.filename] == nil, !inFlight.contains(id.filename) else { return }
        inFlight.insert(id.filename)
        defer { inFlight.remove(id.filename) }
        guard let data = try? await store.load(id), let image = Self.decode(data) else { return }
        cache[id.filename] = image
    }

    public func preload(_ records: [Record], using store: any PhotoStore) async {
        for record in records {
            await load(record.photoID, using: store)
        }
    }

    private static func decode(_ data: Data) -> Image? {
        #if canImport(UIKit)
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #else
        return nil
        #endif
    }
}
