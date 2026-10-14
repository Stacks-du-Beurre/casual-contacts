import SwiftUI
import Testing
@testable import Visuals

@MainActor @Suite struct PhotoEdgeFadeMaskTests {
    @Test func maskIsCachedAndKeepsCenterOpaqueAndEdgesClear() throws {
        let first = try #require(PhotoEdgeFadeMask.bitmap(size: CGSize(width: 400, height: 600)))
        let second = try #require(PhotoEdgeFadeMask.bitmap(size: CGSize(width: 400, height: 600)))
        #expect(first === second)
        let data = try #require(first.dataProvider?.data)
        let pixels = Array(data as Data)
        let center = 128 * first.bytesPerRow + 128 * 4 + 3
        #expect(pixels[center] == 255)
        #expect(pixels[128 * first.bytesPerRow + 3] == 0)
        let halfway = pixels[128 * first.bytesPerRow + 19 * 4 + 3]
        #expect(halfway > 100 && halfway < 160)
        #expect(PhotoEdgeFadeMask.bitmap(size: .zero) == nil)
    }
}
