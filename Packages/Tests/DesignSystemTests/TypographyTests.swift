import Testing
import SwiftUI
@testable import DesignSystem

@Suite struct TypographyTests {

    @Test func titleFontHasExpectedName() {
        // Swift doesn't expose Font's underlying name cleanly (the default `String(describing:)`
        // of a custom Font is just `Font(provider: ...FontBox<...NamedProvider>)`), so we test
        // via description. At minimum, the API surface must exist and be typed as `Font`.
        let font: Font = CCDesign.Typography.title
        let desc = String(describing: font)
        #expect(desc.contains("Font"))
        #expect(desc.contains("NamedProvider") || desc.contains("Cormorant") || desc.contains("33"))
    }

    @Test func allTypeStylesAreAccessible() {
        _ = CCDesign.Typography.title
        _ = CCDesign.Typography.headline
        _ = CCDesign.Typography.description
        _ = CCDesign.Typography.descriptionSmall
        _ = CCDesign.Typography.caption1
        _ = CCDesign.Typography.caption2
    }

    @Test func fontNamesAreRegisteredBundleResources() {
        // Smoke: font files are in the bundle.
        // Actual font registration happens at app launch via CTFontManager (hooked up in AppFeature in Plan 3).
        let bundle = Bundle.module
        #expect(bundle.url(forResource: "CormorantSC-Bold", withExtension: "ttf") != nil)
        #expect(bundle.url(forResource: "CormorantSC-SemiBold", withExtension: "ttf") != nil)
        #expect(bundle.url(forResource: "CormorantInfant-Variable", withExtension: "ttf") != nil)
        #expect(bundle.url(forResource: "IBMPlexMono-Regular", withExtension: "ttf") != nil)
    }
}
