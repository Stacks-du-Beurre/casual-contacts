import SwiftUI
import DesignSystem

public struct AboutView: View {

    @Environment(\.locale) private var locale

    public init() {}

    public var body: some View {
        List {
            Section(FeatureSettingsLocalization.string("Casual Contacts", locale: locale)) {
                FeatureSettingsLocalization.text("Version 1.0", locale: locale)
                    .font(CCDesign.Typography.caption1)
                FeatureSettingsLocalization.text("Made by Stacks du Beurre", locale: locale)
                    .font(CCDesign.Typography.description)
            }
            Section(FeatureSettingsLocalization.string("Contact", locale: locale)) {
                Link("hello@stacksdubeurre.com", destination: URL(string: "mailto:hello@stacksdubeurre.com")!)
            }
            Section(FeatureSettingsLocalization.string("Acknowledgments", locale: locale)) {
                FeatureSettingsLocalization.text("Cormorant SC & Cormorant Infant — Catharsis Fonts, SIL OFL", locale: locale)
                FeatureSettingsLocalization.text("IBM Plex Mono — IBM Corp, SIL OFL", locale: locale)
            }
        }
        .navigationTitle(FeatureSettingsLocalization.string("About", locale: locale))
    }
}
