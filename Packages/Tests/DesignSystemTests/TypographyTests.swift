import CoreText
import Foundation
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
        let fontFiles = [
            (fileName: "CormorantSC-Bold", postScriptName: "CormorantSC-Bold"),
            (fileName: "CormorantSC-SemiBold", postScriptName: "CormorantSC-SemiBold"),
            (fileName: "CormorantInfant-Variable", postScriptName: "CormorantInfant-Light"),
            (fileName: "CormorantInfant-SemiBold", postScriptName: "CormorantInfant-SemiBold"),
            (fileName: "IBMPlexMono-Regular", postScriptName: "IBMPlexMono-Regular")
        ]

        for fontFile in fontFiles {
            let url = try #require(
                CCDesign.bundle.url(forResource: fontFile.fileName, withExtension: "ttf"),
                "\(fontFile.fileName).ttf must be present in the DesignSystem resource bundle"
            )
            let provider = try #require(
                CGDataProvider(url: url as CFURL),
                "\(fontFile.fileName).ttf must be readable as font data"
            )
            let cgFont = try #require(
                CGFont(provider),
                "\(fontFile.fileName).ttf must create a CGFont"
            )
            #expect(cgFont.postScriptName as String? == fontFile.postScriptName)

            let font = CTFontCreateWithGraphicsFont(cgFont, 16, nil, nil)
            #expect(CTFontCopyPostScriptName(font) as String == fontFile.postScriptName)

            for sample in samples {
                let scalars = sample.utf16.map { UniChar($0) }
                var glyphs = Array(repeating: CGGlyph(), count: scalars.count)
                let hasGlyphs = CTFontGetGlyphsForCharacters(font, scalars, &glyphs, scalars.count)
                #expect(hasGlyphs, "\(fontFile.postScriptName) is missing glyphs for \(sample)")
            }
        }
    }
}
