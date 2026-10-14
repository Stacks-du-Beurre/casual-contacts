import CoreGraphics
import Testing
@testable import DesignSystem

@Suite struct MirroredGradientTileTests {
    @Test func decodedSourcesAreBoundedAndPreserveOpaqueColor() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 2048, height: 1024,
                                           bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                           bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2048, height: 1024))
        let source = try #require(context.makeImage())
        let decoded = try #require(CCDesign.GradientBackdrop.decodedGradientSource(source))
        #expect(decoded.width == 768)
        #expect(decoded.height == 384)
        let data = try #require(decoded.dataProvider?.data)
        let bytes = try #require(CFDataGetBytePtr(data))
        let originalData = try #require(source.dataProvider?.data)
        let originalBytes = try #require(CFDataGetBytePtr(originalData))
        for channel in 0..<3 {
            #expect(abs(Int(bytes[channel]) - Int(originalBytes[channel])) <= 1)
        }
        #expect(bytes[3] == 255)
    }

    @Test func transientTilesHaveBoundedDimensions() {
        let landscape = CCDesign.GradientBackdrop.renderTileSize(width: 688, height: 416)
        #expect(landscape.width == 192)
        #expect(landscape.height == 116)
        let portrait = CCDesign.GradientBackdrop.renderTileSize(width: 192, height: 416)
        #expect(portrait.width == 89)
        #expect(portrait.height == 192)
        let small = CCDesign.GradientBackdrop.renderTileSize(width: 80, height: 100)
        #expect(small.width == 80)
        #expect(small.height == 100)
    }
}
