import SwiftUI
import CoreGraphics

/// The same separable edge fade as two nested gradient masks, precomposed once
/// into a small alpha texture. No photo pixels are cached or modified here.
@MainActor enum PhotoEdgeFadeMask {
    private final class Entry {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }
    private static let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.totalCostLimit = 2 * 1024 * 1024
        return cache
    }()
    static func bitmap(size: CGSize) -> CGImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let fade = min(80, min(size.width, size.height) * 0.15)
        let x = fade / size.width
        let y = fade / size.height
        let key = "\(Int((x * 1000).rounded())):\(Int((y * 1000).rounded()))" as NSString
        if let entry = cache.object(forKey: key) { return entry.image }
        let side = 256
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let colors = [CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 0.5),
                      CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 1),
                      CGColor(gray: 1, alpha: 0.5), CGColor(gray: 1, alpha: 0)] as CFArray
        guard let horizontal = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                          locations: [0, x / 2, x, 1 - x, 1 - x / 2, 1]),
              let vertical = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                        locations: [0, y / 2, y, 1 - y, 1 - y / 2, 1]) else { return nil }
        context.drawLinearGradient(horizontal, start: .zero, end: CGPoint(x: side, y: 0), options: [])
        context.setBlendMode(.destinationIn)
        context.drawLinearGradient(vertical, start: .zero, end: CGPoint(x: 0, y: side), options: [])
        context.clear(CGRect(x: 0, y: 0, width: side, height: 1))
        context.clear(CGRect(x: 0, y: side - 1, width: side, height: 1))
        context.clear(CGRect(x: 0, y: 0, width: 1, height: side))
        context.clear(CGRect(x: side - 1, y: 0, width: 1, height: side))
        guard let image = context.makeImage() else { return nil }
        cache.setObject(Entry(image), forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }
}
