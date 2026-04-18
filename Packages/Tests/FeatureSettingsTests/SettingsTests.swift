import Testing
import SwiftUI
@testable import FeatureSettings

@MainActor
@Suite struct SettingsTests {

    @Test func settingsSheetInstantiates() {
        _ = SettingsSheet(onAbout: {}, onDismiss: {}).body
    }

    @Test func aboutViewInstantiates() {
        _ = AboutView().body
    }
}
