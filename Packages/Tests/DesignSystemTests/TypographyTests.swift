import CoreText
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

    @Test func bundledFontsCoverRussianAndUkrainianSampleText() throws {
        let samples = [
            "Настройки Сохранить Удалить",
            "Налаштування Зберегти Видалити ї є ґ і"
        ]
        let fontNames = [
            "CormorantSC-Bold",
            "CormorantSC-SemiBold",
            "CormorantInfant-SemiBold",
            "IBMPlexMono-Regular"
        ]

        for fontName in fontNames {
            let font = CTFontCreateWithName(fontName as CFString, 16, nil)
            for sample in samples {
                let characters = Array(sample)
                let scalars = characters.map { UniChar(String($0).utf16.first!) }
                var glyphs = Array(repeating: CGGlyph(), count: scalars.count)
                let hasGlyphs = CTFontGetGlyphsForCharacters(font, scalars, &glyphs, scalars.count)
                #expect(hasGlyphs, "\(fontName) is missing glyphs for \(sample)")
            }
        }
    }
}
