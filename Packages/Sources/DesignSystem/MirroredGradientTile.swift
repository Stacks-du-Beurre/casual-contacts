import SwiftUI
import CoreGraphics
#if os(iOS)
import UIKit
#else
import AppKit
#endif

public extension CCDesign.GradientBackdrop {
    /// One reusable 2×2 mirrored repeat cell, cropped before mirroring so the
    /// normal central tile retains the same scaled-to-fill composition.
    @MainActor func mirroredTile(aspect: CGFloat, blend: Bool) -> (image: Image, tileWidth: CGFloat)? {
        let aspect = max(0.1, min(10, aspect))
        let key = "\(assetName):\(Int((aspect * 1000).rounded())):\(blend)" as NSString
        if let tile = GradientTileCache.images.object(forKey: key) {
            return (Image(decorative: tile.image, scale: 1), CGFloat(tile.image.width) / 2)
        }
        // Decode/downsample each source once, rather than resampling its full
        // asset pixels for every transient aspect ratio during a zoom.
        let sourceKey = assetName as NSString
        let source: CGImage
        if let cached = GradientTileCache.sources.object(forKey: sourceKey) {
            source = cached.image
        } else {
            #if os(iOS)
            guard let original = UIImage(named: assetName, in: .module, compatibleWith: nil)?.cgImage else { return nil }
            #else
            guard let original = Bundle.module.image(forResource: assetName)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
            #endif
            source = Self.decodedGradientSource(original) ?? original
            GradientTileCache.sources.setObject(GradientTileImage(source), forKey: sourceKey,
                                               cost: source.bytesPerRow * source.height)
        }
        let width = min(source.width, Int(CGFloat(source.height) * aspect))
        let height = min(source.height, Int(CGFloat(source.width) / aspect))
        let rendered = Self.renderTileSize(width: width, height: height)
        guard let crop = source.cropping(to: CGRect(x: (source.width - width) / 2,
                                                    y: (source.height - height) / 2,
                                                    width: width, height: height)),
              let context = CGContext(data: nil, width: rendered.width * 2,
                                      height: rendered.height * 2,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Smooth gradient artwork does not need a source-resolution offscreen
        // surface for every transient aspect during card expansion.
        let tileWidth = rendered.width
        let tileHeight = rendered.height
        context.interpolationQuality = .high
        for row in 0..<2 {
            for column in 0..<2 {
                context.saveGState()
                context.translateBy(x: CGFloat(column * tileWidth), y: CGFloat(row * tileHeight))
                if column == 1 { context.translateBy(x: CGFloat(tileWidth), y: 0); context.scaleBy(x: -1, y: 1) }
                if row == 1 { context.translateBy(x: 0, y: CGFloat(tileHeight)); context.scaleBy(x: 1, y: -1) }
                let rect = CGRect(x: 0, y: 0, width: tileWidth, height: tileHeight)
                context.draw(crop, in: rect)
                if blend {
                    context.translateBy(x: CGFloat(tileWidth), y: CGFloat(tileHeight))
                    context.scaleBy(x: -1, y: -1)
                    context.setAlpha(0.5)
                    context.draw(crop, in: rect)
                }
                context.restoreGState()
            }
        }
        guard let image = context.makeImage() else { return nil }
        GradientTileCache.images.setObject(GradientTileImage(image), forKey: key, cost: image.bytesPerRow * image.height)
        return (Image(decorative: image, scale: 1), CGFloat(tileWidth))
    }
    static func decodedGradientSource(_ image: CGImage) -> CGImage? {
        let scale = min(1, 768.0 / Double(max(image.width, image.height)))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    static func renderTileSize(width: Int, height: Int) -> (width: Int, height: Int) {
        let scale = min(1, 192.0 / Double(max(width, height)))
        return (max(1, Int((Double(width) * scale).rounded())),
                max(1, Int((Double(height) * scale).rounded())))
    }

}

private final class GradientTileImage {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

@MainActor private enum GradientTileCache {
    static let sources: NSCache<NSString, GradientTileImage> = {
        let cache = NSCache<NSString, GradientTileImage>()
        cache.totalCostLimit = 8 * 1024 * 1024
        return cache
    }()
    static let images: NSCache<NSString, GradientTileImage> = {
        let cache = NSCache<NSString, GradientTileImage>()
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()
}
