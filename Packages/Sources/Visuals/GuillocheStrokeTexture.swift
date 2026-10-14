import SwiftUI
import CoreGraphics
import Foundation

/// Reuse stable stroke artwork; motion changes transforms, not its pixels.
@MainActor enum GuillocheStrokeTexture {
    private final class Entry {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }
    private static let cache: NSCache<NSString, Entry> = {
        let value = NSCache<NSString, Entry>()
        value.totalCostLimit = 48 * 1024 * 1024
        return value
    }()

    static func image(paths: [Path], size: CGSize, offset: CGFloat = 0,
                      opacity: Double = 1, scale: CGFloat = 2) -> Image? {
        bitmap(paths: paths, size: size, offset: offset, opacity: opacity, scale: scale)
            .map { Image(decorative: $0, scale: scale) }
    }

    static func bitmap(paths: [Path], size: CGSize, offset: CGFloat = 0,
                       opacity: Double = 1, scale: CGFloat = 2) -> CGImage? {
        var hash = Hasher()
        for path in paths {
            // CGPath's generic CF hash can collide for distinct outlines.
            // Include the actual commands and coordinates in the cache key.
            path.cgPath.applyWithBlock { pointer in
                let element = pointer.pointee
                hash.combine(element.type.rawValue)
                let count: Int
                switch element.type {
                case .moveToPoint, .addLineToPoint: count = 1
                case .addQuadCurveToPoint: count = 2
                case .addCurveToPoint: count = 3
                case .closeSubpath: count = 0
                @unknown default: count = 0
                }
                for index in 0..<count {
                    hash.combine(element.points[index].x)
                    hash.combine(element.points[index].y)
                }
            }
        }
        let key = "\(hash.finalize()):\(size.width):\(size.height):\(offset):\(opacity):\(scale)" as NSString
        if let entry = cache.object(forKey: key) {
            return entry.image
        }
        let width = max(1, Int((size.width * scale).rounded(.up)))
        let height = max(1, Int((size.height * scale).rounded(.up)))
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: offset, y: offset)
        context.setStrokeColor(CGColor(gray: 1, alpha: max(0, min(1, opacity))))
        context.setLineWidth(0.5)
        context.setLineJoin(.miter)
        for path in paths {
            context.addPath(path.cgPath)
            context.strokePath()
        }
        guard let image = context.makeImage() else { return nil }
        cache.setObject(Entry(image), forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }
}
