import Testing
import SwiftUI
import CoreModels
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

    @Test func settingsSheetAcceptsLanguagePreferenceBinding() {
        @State var preference = AppLanguagePreference.system
        _ = SettingsSheet(onAbout: {}, languagePreference: $preference).body
    }

    @Test func allLanguagePreferencesHaveDisplayNames() {
        for preference in AppLanguagePreference.allCases {
            #expect(String(localized: preference.displayName).isEmpty == false)
        }
    }

    @Test func inListDeveloperSettingsPanelInstantiates() {
        _ = InListDeveloperSettingsPanel(onClose: {}).body
    }

    @Test func aboutViewInstantiates() {
        _ = AboutView().body
    }
}
