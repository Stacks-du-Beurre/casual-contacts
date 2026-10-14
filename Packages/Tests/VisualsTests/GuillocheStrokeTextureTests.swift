import SwiftUI
import Testing
@testable import Visuals

@MainActor @Suite struct GuillocheStrokeTextureTests {
    @Test func repeatedArtworkReusesTheSameBitmap() throws {
        let path = Path(CGRect(x: 3, y: 7, width: 10, height: 12))
        let first = try #require(GuillocheStrokeTexture.bitmap(paths: [path], size: CGSize(width: 30, height: 40)))
        let second = try #require(GuillocheStrokeTexture.bitmap(paths: [path], size: CGSize(width: 30, height: 40)))
        #expect(first === second)
        #expect(first.width == 60)
        #expect(first.height == 80)
    }

    @Test func opacityAndArtworkHaveSeparateCacheEntries() throws {
        let path = Path(CGRect(x: 4, y: 6, width: 8, height: 12))
        let first = try #require(GuillocheStrokeTexture.bitmap(paths: [path], size: CGSize(width: 30, height: 40), opacity: 0.2))
        let stronger = try #require(GuillocheStrokeTexture.bitmap(paths: [path], size: CGSize(width: 30, height: 40), opacity: 0.4))
        let other = try #require(GuillocheStrokeTexture.bitmap(paths: [Path(CGRect(x: 5, y: 6, width: 8, height: 12))], size: CGSize(width: 30, height: 40), opacity: 0.2))
        #expect(first !== stronger)
        #expect(first !== other)
    }
    @Test func cachedTexturePreservesPathOrientation() throws {
        let bitmap = try #require(GuillocheStrokeTexture.bitmap(
            paths: [Path(CGRect(x: 4, y: 6, width: 8, height: 12))],
            size: CGSize(width: 30, height: 40)
        ))
        let data = try #require(bitmap.dataProvider?.data)
        let bytes = Array(data as Data)
        let occupiedRows = (0..<bitmap.height).filter { y in
            (0..<bitmap.width).contains { x in bytes[y * bitmap.bytesPerRow + x * 4 + 3] > 0 }
        }
        #expect(try #require(occupiedRows.min()) < 20)
        #expect(try #require(occupiedRows.max()) < 40)
    }

}
