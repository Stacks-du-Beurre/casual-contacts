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
        #if os(iOS)
        guard let source = UIImage(named: assetName, in: .module, compatibleWith: nil)?.cgImage else { return nil }
        #else
        guard let source = Bundle.module.image(forResource: assetName)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        #endif
        let width = min(source.width, Int(CGFloat(source.height) * aspect))
        let height = min(source.height, Int(CGFloat(source.width) / aspect))
        guard let crop = source.cropping(to: CGRect(x: (source.width - width) / 2,
                                                    y: (source.height - height) / 2,
                                                    width: width, height: height)),
              let context = CGContext(data: nil, width: width * 2, height: height * 2,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        for row in 0..<2 {
            for column in 0..<2 {
                context.saveGState()
                context.translateBy(x: CGFloat(column * width), y: CGFloat(row * height))
                if column == 1 { context.translateBy(x: CGFloat(width), y: 0); context.scaleBy(x: -1, y: 1) }
                if row == 1 { context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1) }
                let rect = CGRect(x: 0, y: 0, width: width, height: height)
                context.draw(crop, in: rect)
                if blend {
                    context.translateBy(x: CGFloat(width), y: CGFloat(height))
                    context.scaleBy(x: -1, y: -1)
                    context.setAlpha(0.5)
                    context.draw(crop, in: rect)
                }
                context.restoreGState()
            }
        }
        guard let image = context.makeImage() else { return nil }
        GradientTileCache.images.setObject(GradientTileImage(image), forKey: key, cost: image.bytesPerRow * image.height)
        return (Image(decorative: image, scale: 1), CGFloat(width))
    }
}

private final class GradientTileImage {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

@MainActor private enum GradientTileCache {
    static let images: NSCache<NSString, GradientTileImage> = {
        let cache = NSCache<NSString, GradientTileImage>()
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()
}
