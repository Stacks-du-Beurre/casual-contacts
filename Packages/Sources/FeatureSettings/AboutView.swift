import SwiftUI
import DesignSystem

public struct AboutView: View {

    public init() {}

    public var body: some View {
        List {
            Section("Casual Contacts") {
                Text("Version 1.0")
                    .font(CCDesign.Typography.caption1)
                Text("Made by Stacks du Beurre")
                    .font(CCDesign.Typography.description)
            }
            Section("Contact") {
                Link("hello@stacksdubeurre.com", destination: URL(string: "mailto:hello@stacksdubeurre.com")!)
            }
            Section("Acknowledgments") {
                Text("Cormorant SC & Cormorant Infant — Catharsis Fonts, SIL OFL")
                Text("IBM Plex Mono — IBM Corp, SIL OFL")
            }
        }
        .navigationTitle("About")
    }
}
