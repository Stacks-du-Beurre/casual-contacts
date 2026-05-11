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

    @Test func featureSettingsBundleLocalizesSettingsLanguage() {
        #expect(FeatureSettingsLocalization.localizedString("settings.language", localeIdentifier: "ru") == "Язык")
        #expect(FeatureSettingsLocalization.localizedString("settings.language", localeIdentifier: "uk") == "Мова")
    }

    @Test func featureSettingsBundleLocalizesLanguageDisplayName() {
        #expect(FeatureSettingsLocalization.localizedString(AppLanguagePreference.russian.displayNameKey, localeIdentifier: "ru") == "Русский")
        #expect(FeatureSettingsLocalization.localizedString(AppLanguagePreference.ukrainian.displayNameKey, localeIdentifier: "uk") == "Українська")
    }

    @Test func featureSettingsLocalizationUsesActiveLocaleForRemainingUILiterals() {
        #expect(FeatureSettingsLocalization.string("Back", locale: Locale(identifier: "ru")) == "Назад")
        #expect(FeatureSettingsLocalization.string("Motion Debug", locale: Locale(identifier: "uk")) == "Налагодження руху")
        #expect(
            FeatureSettingsLocalization.string("Source: %@", locale: Locale(identifier: "ru"), "Relative") ==
            "Источник: Relative"
        )
        #expect(
            FeatureSettingsLocalization.string("Casual Contacts Version %@", locale: Locale(identifier: "uk"), "1.0") ==
            "Casual Contacts, версія 1.0"
        )
    }

    @Test func inListDeveloperSettingsPanelInstantiates() {
        _ = InListDeveloperSettingsPanel(onClose: {}).body
    }

    @Test func aboutViewInstantiates() {
        _ = AboutView().body
    }
}
