import Testing
import SwiftUI
import DesignSystem
@testable import FeatureSettings

@MainActor
@Suite struct SettingsChromeTests {

    @Test func rowInstantiatesWithoutTap() {
        _ = SettingsRow<EmptyView>(label: "Sync", onTap: nil) { EmptyView() }.body
    }

    @Test func rowInstantiatesWithTap() {
        _ = SettingsRow<Image>(label: "About", onTap: {}) { Image(systemName: "chevron.right") }.body
    }

    @Test func groupInstantiates() {
        _ = SettingsGroup { Text("row") }.body
    }

    @Test func dividerInstantiates() {
        _ = SettingsDivider().body
    }

    @Test func paletteTokensDifferByScheme() {
        #expect(SettingsPalette.sheetBackground(.dark) != SettingsPalette.sheetBackground(.light))
        #expect(SettingsPalette.rowBackground(.dark) != SettingsPalette.rowBackground(.light))
        #expect(SettingsPalette.border(.dark) != SettingsPalette.border(.light))
        #expect(SettingsPalette.label(.dark) != SettingsPalette.label(.light))
    }

    @Test func paletteDarkMatchesD3() {
        #expect(SettingsPalette.sheetBackground(.dark) == CCDesign.Colors.D3)
        #expect(SettingsPalette.rowBackground(.dark) == CCDesign.Colors.D2)
        #expect(SettingsPalette.border(.dark) == CCDesign.Colors.D1)
    }

    @Test func paletteLightMatchesL2() {
        #expect(SettingsPalette.sheetBackground(.light) == CCDesign.Colors.L2)
        #expect(SettingsPalette.rowBackground(.light) == CCDesign.Colors.L1)
        #expect(SettingsPalette.border(.light) == CCDesign.Colors.L3)
    }
}
