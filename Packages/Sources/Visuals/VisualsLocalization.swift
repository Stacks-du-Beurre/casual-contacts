import Foundation
import SwiftUI
import CoreModels

enum VisualsLocalization {
    private static let catalog = StringCatalog.load()

    static func timeOfDayDisplayName(_ timeOfDay: TimeOfDay, locale: Locale) -> String {
        string("timeOfDay.\(timeOfDay.rawValue)", locale: locale)
    }

    static func moonPhaseDisplayName(_ phase: MoonPhase, locale: Locale) -> String {
        string("moonPhase.\(phase.rawValue)", locale: locale)
    }

    static func zodiacDisplayName(_ sign: ZodiacSign, locale: Locale) -> String {
        string("zodiac.\(sign.rawValue)", locale: locale)
    }

    static func string(_ key: String, locale: Locale) -> String {
        if let value = bundleValue(for: key, locale: locale) {
            return value
        }

        let systemValue = String(localized: String.LocalizationValue(key), bundle: .module, locale: locale)
        guard systemValue == key else {
            return systemValue
        }
        return catalogValue(for: key, locale: locale) ?? systemValue
    }

    private static func bundleValue(for key: String, locale: Locale) -> String? {
        for identifier in candidateIdentifiers(for: locale) {
            guard
                let url = Bundle.module.url(
                    forResource: "Localizable",
                    withExtension: "strings",
                    subdirectory: "\(identifier).lproj"
                ),
                let data = try? Data(contentsOf: url),
                let strings = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
                let value = strings[key],
                value != key
            else {
                continue
            }

            return value
        }
        return nil
    }

    private static func catalogValue(for key: String, locale: Locale) -> String? {
        guard
            let entry = catalog.strings[key]
        else {
            return nil
        }

        for identifier in candidateIdentifiers(for: locale) {
            if let value = entry.localizations?[identifier]?.stringUnit.value {
                return value
            }
        }
        return nil
    }

    private static func candidateIdentifiers(for locale: Locale) -> [String] {
        let normalized = locale.identifier.replacingOccurrences(of: "_", with: "-")
        let language = languageIdentifier(for: locale)
        return [locale.identifier, normalized, language].filter { !$0.isEmpty }
    }

    private static func languageIdentifier(for locale: Locale) -> String {
        let normalized = locale.identifier.replacingOccurrences(of: "_", with: "-")
        return normalized.split(separator: "-").first.map(String.init) ?? locale.identifier
    }
}

private struct StringCatalog: Decodable {
    let strings: [String: StringCatalogEntry]

    static func load() -> StringCatalog {
        guard
            let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"),
            let data = try? Data(contentsOf: url),
            let catalog = try? JSONDecoder().decode(StringCatalog.self, from: data)
        else {
            return StringCatalog(strings: [:])
        }
        return catalog
    }
}

private struct StringCatalogEntry: Decodable {
    let localizations: [String: StringCatalogLocalization]?
}

private struct StringCatalogLocalization: Decodable {
    let stringUnit: StringCatalogUnit
}

private struct StringCatalogUnit: Decodable {
    let value: String
}
