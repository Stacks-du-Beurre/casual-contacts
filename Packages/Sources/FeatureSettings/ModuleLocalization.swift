import Foundation
import SwiftUI
import CoreModels

enum FeatureSettingsLocalization {
    static func text(_ key: String, locale: Locale) -> Text {
        Text(string(key, locale: locale))
    }

    static func resource(_ key: String) -> LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(key), bundle: .module)
    }

    static func languageDisplayName(for preference: AppLanguagePreference, locale: Locale) -> String {
        string(preference.displayNameKey, locale: locale)
    }

    static func languageDisplayName(for preference: AppLanguagePreference) -> LocalizedStringResource {
        resource(preference.displayNameKey)
    }

    static func localizedString(_ key: String, localeIdentifier: String) -> String {
        string(key, locale: Locale(identifier: localeIdentifier))
    }

    static func string(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        let format = localizedFormat(key, locale: locale)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }

    private static func localizedFormat(_ key: String, locale: Locale) -> String {
        let systemValue = String(localized: String.LocalizationValue(key), bundle: .module, locale: locale)
        if systemValue != key {
            return systemValue
        }

        return catalogValue(for: key, locale: locale) ?? systemValue
    }

    private static func catalogValue(for key: String, locale: Locale) -> String? {
        guard let localizations = catalog[key] else { return nil }

        for identifier in candidateIdentifiers(for: locale) {
            if let value = localizations[identifier] {
                return value
            }
        }

        return nil
    }

    private static let catalog: [String: [String: String]] = {
        guard
            let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"),
            let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let strings = root["strings"] as? [String: Any]
        else {
            return [:]
        }

        return strings.reduce(into: [String: [String: String]]()) { result, pair in
            guard
                let entry = pair.value as? [String: Any],
                let localizations = entry["localizations"] as? [String: Any]
            else {
                return
            }

            let values = localizations.reduce(into: [String: String]()) { valueResult, localizationPair in
                guard
                    let localization = localizationPair.value as? [String: Any],
                    let stringUnit = localization["stringUnit"] as? [String: Any],
                    let value = stringUnit["value"] as? String
                else {
                    return
                }

                valueResult[localizationPair.key] = value
            }

            result[pair.key] = values
        }
    }()

    private static func candidateIdentifiers(for locale: Locale) -> [String] {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        let language = languageIdentifier(for: locale)
        return [identifier, language, "en"].removingDuplicates()
    }

    private static func languageIdentifier(for locale: Locale) -> String {
        if #available(iOS 16, macOS 13, tvOS 16, watchOS 9, *) {
            return locale.language.languageCode?.identifier ?? "en"
        } else {
            return locale.identifier.split(separator: "_").first.map(String.init) ?? "en"
        }
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
