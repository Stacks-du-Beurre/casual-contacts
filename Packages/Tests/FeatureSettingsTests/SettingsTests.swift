import Testing
import SwiftUI
@testable import FeatureSettings

@MainActor
@Suite struct SettingsTests {

    @Test func settingsSheetInstantiates() {
        _ = SettingsSheet(onAbout: {}).body
    }

    @Test func settingsSheetAcceptsLocationToggleHostCallback() {
        _ = SettingsSheet(onAbout: {}, onLocationToggleTapped: {}).body
    }

    @Test func settingsSheetAcceptsInListDeveloperSettingsCallback() {
        _ = SettingsSheet(onAbout: {}, onShowInListDeveloperSettings: {}).body
    }

    @Test func inListDeveloperSettingsPanelInstantiates() {
        _ = InListDeveloperSettingsPanel(onClose: {}).body
    }

    @Test func aboutViewInstantiates() {
        _ = AboutView().body
    }
}
