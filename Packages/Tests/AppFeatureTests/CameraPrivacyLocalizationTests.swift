import Foundation
import Testing
@testable import AppFeature

@Suite struct CameraPrivacyLocalizationTests {
    @Test func privacyLinksFollowTheAppLanguage() {
        for (language, path) in [("en_US", "/privacy.html"), ("ru_RU", "/ru/privacy.html"), ("uk_UA", "/uk/privacy.html"), ("fr_FR", "/privacy.html")] {
            let url = ModuleLocalization.privacyPolicyURL(locale: Locale(identifier: language))
            #expect(url.host == "casualcontacts.app")
            #expect(url.path == path)
            #expect(url.fragment == "face-data")
        }
    }

    @Test func cameraCopyUsesRussianAndUkrainianCatalogs() {
        for language in ["ru", "uk"] {
            let locale = Locale(identifier: language)
            for key in ["CAMERA PERSPECTIVE", "Continue to camera permission", "Enable camera in Settings", "Gyro only; camera off", "Use camera for face perspective"] {
                #expect(ModuleLocalization.string(key, locale: locale) != key)
            }
        }
    }
}
