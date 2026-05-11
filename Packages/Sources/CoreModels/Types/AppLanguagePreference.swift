import SwiftUI

public enum AppLanguagePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case russian = "ru"
    case ukrainian = "uk"

    public var id: String { rawValue }

    public init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .system
    }

    public var localeIdentifier: String? {
        switch self {
        case .system:
            nil
        case .english:
            "en"
        case .russian:
            "ru"
        case .ukrainian:
            "uk"
        }
    }

    public var displayNameKey: String {
        switch self {
        case .system:
            "language.system"
        case .english:
            "language.english"
        case .russian:
            "language.russian"
        case .ukrainian:
            "language.ukrainian"
        }
    }

    public var displayName: LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(displayNameKey))
    }
}
