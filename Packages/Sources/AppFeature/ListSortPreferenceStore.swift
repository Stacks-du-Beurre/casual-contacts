import Foundation
import CoreModels
import FeatureList

public protocol ListSortPreferenceStore: AnyObject {
    var sortOption: SortOption? { get set }
}

public final class UserDefaultsListSortPreferenceStore: ListSortPreferenceStore {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "listSortOption"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public var sortOption: SortOption? {
        get {
            guard let raw = defaults.string(forKey: key) else { return nil }
            return SortOption(rawValue: raw)
        }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}

public final class InMemoryListSortPreferenceStore: ListSortPreferenceStore {
    public var sortOption: SortOption?

    public init(sortOption: SortOption? = nil) {
        self.sortOption = sortOption
    }
}

public enum ListSortPreferenceResolver {
    public static func initialSortOption(
        stored: SortOption?,
        authorization: LocationAuthorization
    ) -> SortOption {
        switch stored {
        case .some(.distance) where authorization != .authorized:
            return .alphabetical
        case let .some(option):
            return option
        case nil:
            return authorization == .authorized ? .distance : .alphabetical
        }
    }
}
