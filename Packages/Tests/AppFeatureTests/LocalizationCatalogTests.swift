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

        let discoveredCatalogPaths = try discoveredStringCatalogPaths(in: packageRoot)
        let expectedCatalogPaths = Set(catalogPaths)
        let discoveredCatalogPathSet = Set(discoveredCatalogPaths)
        let missingCatalogPaths = expectedCatalogPaths.subtracting(discoveredCatalogPathSet).sorted()
        let extraCatalogPaths = discoveredCatalogPathSet.subtracting(expectedCatalogPaths).sorted()
        #expect(
            discoveredCatalogPathSet == expectedCatalogPaths,
            "Catalog path list is out of sync; missing: \(missingCatalogPaths), extra: \(extraCatalogPaths)"
        )

        for path in catalogPaths {
            let url = packageRoot.appendingPathComponent(path)
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(StringCatalog.self, from: data)

            #expect(!catalog.strings.isEmpty, "\(path) has no strings")

            for key in catalog.strings.keys {
                let localizations = catalog.strings[key]?.localizations ?? [:]
                for language in ["en", "ru", "uk"] {
                    let localization = localizations[language]
                    let unsupportedFields = localization?.unsupportedFields ?? []
                    #expect(
                        unsupportedFields.isEmpty,
                        "\(path) unsupported \(unsupportedFields.joined(separator: ", ")) for \(language) \(key); only stringUnit localizations are supported by this test"
                    )

                    let stringUnit = localization?.stringUnit
                    #expect(stringUnit != nil, "\(path) missing \(language) stringUnit for \(key); variations/plurals are not supported by this test yet")

                    let value = stringUnit?.value.trimmingCharacters(in: .whitespacesAndNewlines)
                    #expect(value?.isEmpty == false, "\(path) missing \(language) for \(key)")
                }
            }
        }
    }
}

private func discoveredStringCatalogPaths(in packageRoot: URL) throws -> [String] {
    let sourcesURL = packageRoot.appendingPathComponent("Sources")
    let sourceURLs = try FileManager.default.contentsOfDirectory(
        at: sourcesURL,
        includingPropertiesForKeys: nil
    )

    return sourceURLs.compactMap { sourceURL in
        let catalogURL = sourceURL.appendingPathComponent("Resources/Localizable.xcstrings")
        guard FileManager.default.fileExists(atPath: catalogURL.path) else { return nil }
        return "Sources/\(sourceURL.lastPathComponent)/Resources/Localizable.xcstrings"
    }
    .sorted()
}

private struct StringCatalog: Decodable {
    let strings: [String: Entry]

    struct Entry: Decodable {
        let localizations: [String: Localization]?
    }

    struct Localization: Decodable {
        let stringUnit: StringUnit?
        let unsupportedFields: [String]

        private enum CodingKeys: String, CodingKey, CaseIterable {
            case stringUnit
            case variations
            case substitutions
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            stringUnit = try container.decodeIfPresent(StringUnit.self, forKey: .stringUnit)
            unsupportedFields = CodingKeys.allCases
                .filter { $0 != .stringUnit && container.contains($0) }
                .map(\.stringValue)
        }
    }

    struct StringUnit: Decodable {
        let value: String
    }
}
