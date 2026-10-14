import Foundation
import SwiftUI
import Observation
import CoreModels
#if canImport(UIKit)
import UIKit
import CoreImage
import ImageIO
#endif

@MainActor
@Observable
public final class PhotoCache {

    public struct Entry: Sendable {
        public let image: Image
        /// Pixel dimensions of the source image, used by `PhotoLayer` to compute
        /// the offset that places a normalized focus point at container center.
        public let size: CGSize
        public let blurredImage: Image?
    }

    private var cache: [String: Entry] = [:]
    public private(set) var blurredImages: [String: Image] = [:]
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
        #if os(iOS)
        let loadStarted = ProcessInfo.processInfo.systemUptime
        PerformanceDiagnostics.shared.event("photo_load_started")
        #endif
        guard let data = try? await store.load(id) else { return }
        let entry = await Task.detached(priority: .utility) { Self.decode(data) }.value
        guard let entry else { return }
        cache[id.filename] = entry
        blurredImages[id.filename] = entry.blurredImage
        #if os(iOS)
        PerformanceDiagnostics.shared.event("photo_load_completed", values: [
            "durationMS": (ProcessInfo.processInfo.systemUptime - loadStarted) * 1000
        ])
        #endif
    }

    public func preload(_ records: [Record], using store: any PhotoStore) async {
        for record in records {
            await load(record.photoID, using: store)
        }
    }

    public func invalidate(_ id: PhotoID?) {
        guard let id else { return }
        cache.removeValue(forKey: id.filename)
        blurredImages.removeValue(forKey: id.filename)
    }

    nonisolated private static func decode(_ data: Data) -> Entry? {
        #if canImport(UIKit)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 3072,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        // Decode on this utility task, rather than letting UIImage defer full-size
        // camera-image decoding until the first animated frame. Aspect ratio and
        // normalized face coordinates are preserved; the stored photo is untouched.
        return Entry(image: Image(decorative: bitmap, scale: 1, orientation: .up),
                     size: CGSize(width: bitmap.width, height: bitmap.height),
                     blurredImage: blurredImage(data))
        #else
        return nil
        #endif
    }
    #if canImport(UIKit)
    // CIContext is thread-safe and retains rendering resources across photos.
    nonisolated private static let blurContext = CIContext(options: [.cacheIntermediates: false])

    nonisolated private static func blurredImage(_ data: Data) -> Image? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 512
              ] as CFDictionary) else { return nil }
        let image = CIImage(cgImage: thumbnail)
        // Approximately 7 points when enlarged to a 10× phone-width backing.
        // Work at thumbnail resolution; no blur filter runs during card motion.
        let radius = 7 * Double(thumbnail.width) / (393 * 10)
        let blurred = image.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: image.extent)
        guard let bitmap = blurContext.createCGImage(blurred, from: image.extent) else { return nil }
        return Image(decorative: bitmap, scale: 1, orientation: .up)
    }
    #endif

}
