import Testing
@testable import DesignSystem

@Suite struct MirroredGradientTileTests {
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
