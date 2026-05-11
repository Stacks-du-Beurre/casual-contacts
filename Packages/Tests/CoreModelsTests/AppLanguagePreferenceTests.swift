import Testing
import SwiftUI
@testable import CoreModels

@Suite struct AppLanguagePreferenceTests {

    @Test func rawValuesAreStableForPersistence() {
        #expect(AppLanguagePreference.system.rawValue == "system")
        #expect(AppLanguagePreference.english.rawValue == "en")
        #expect(AppLanguagePreference.russian.rawValue == "ru")
        #expect(AppLanguagePreference.ukrainian.rawValue == "uk")
    }

    @Test func localeIdentifierIsNilForSystemDefault() {
        #expect(AppLanguagePreference.system.localeIdentifier == nil)
    }

    @Test func localeIdentifiersMatchAppleLanguageCodes() {
        #expect(AppLanguagePreference.english.localeIdentifier == "en")
        #expect(AppLanguagePreference.russian.localeIdentifier == "ru")
        #expect(AppLanguagePreference.ukrainian.localeIdentifier == "uk")
    }

    @Test func invalidStoredValueFallsBackToSystem() {
        #expect(AppLanguagePreference(storedValue: "de") == .system)
        #expect(AppLanguagePreference(storedValue: "") == .system)
    }
}
