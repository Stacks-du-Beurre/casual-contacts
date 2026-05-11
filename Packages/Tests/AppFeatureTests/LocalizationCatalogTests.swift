import Foundation
import Testing

@Suite struct LocalizationCatalogTests {
    @Test func stringCatalogsContainEnglishRussianAndUkrainianForEveryKey() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let catalogPaths = [
            "Sources/AppFeature/Resources/Localizable.xcstrings",
            "Sources/FeatureCreate/Resources/Localizable.xcstrings",
            "Sources/FeatureDetail/Resources/Localizable.xcstrings",
            "Sources/FeatureList/Resources/Localizable.xcstrings",
            "Sources/FeatureSettings/Resources/Localizable.xcstrings"
        ]

        for path in catalogPaths {
            let url = packageRoot.appendingPathComponent(path)
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(StringCatalog.self, from: data)

            for key in catalog.strings.keys {
                let localizations = catalog.strings[key]?.localizations ?? [:]
                #expect(localizations["en"]?.stringUnit.value.isEmpty == false, "\(path) missing en for \(key)")
                #expect(localizations["ru"]?.stringUnit.value.isEmpty == false, "\(path) missing ru for \(key)")
                #expect(localizations["uk"]?.stringUnit.value.isEmpty == false, "\(path) missing uk for \(key)")
            }
        }
    }
}

private struct StringCatalog: Decodable {
    let strings: [String: Entry]

    struct Entry: Decodable {
        let localizations: [String: Localization]?
    }

    struct Localization: Decodable {
        let stringUnit: StringUnit
    }

    struct StringUnit: Decodable {
        let value: String
    }
}
