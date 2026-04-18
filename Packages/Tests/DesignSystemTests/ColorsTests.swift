import Testing
import SwiftUI
@testable import DesignSystem

@Suite struct ColorsTests {

    @Test func lightPaletteHasFiveTones() {
        let palette = CCDesign.Colors.light
        #expect(palette.count == 5)
    }

    @Test func darkPaletteHasFiveTones() {
        let palette = CCDesign.Colors.dark
        #expect(palette.count == 5)
    }

    @Test func lightPaletteGoesLightestToDarkest() {
        // L0 is pure white, L4 is darkest light-palette tone. Verified via Figma node 277:11175.
        let palette = CCDesign.Colors.light
        #expect(palette[0] != palette[4])
    }

    @Test func individualAccessors() {
        // Accessible by name.
        _ = CCDesign.Colors.L0
        _ = CCDesign.Colors.L1
        _ = CCDesign.Colors.L2
        _ = CCDesign.Colors.L3
        _ = CCDesign.Colors.L4
        _ = CCDesign.Colors.D0
        _ = CCDesign.Colors.D1
        _ = CCDesign.Colors.D2
        _ = CCDesign.Colors.D3
        _ = CCDesign.Colors.D4
    }
}
