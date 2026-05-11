import Foundation

enum ModuleLocalization {
    static func string(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        let format = localizedFormat(key, locale: locale)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }

    private static func localizedFormat(_ key: String, locale: Locale) -> String {
        let systemValue = String(localized: String.LocalizationValue(key), bundle: .module, locale: locale)
        guard languageIdentifier(for: locale) != "en", systemValue == key else {
            return systemValue
        }
        return catalogValue(for: key, locale: locale) ?? systemValue
    }

    private static func catalogValue(for key: String, locale: Locale) -> String? {
        guard
            let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"),
            let data = try? Data(contentsOf: url),
            let catalog = try? JSONDecoder().decode(StringCatalog.self, from: data),
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
