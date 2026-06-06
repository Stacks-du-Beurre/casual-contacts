import Foundation
import CoreModels

public protocol LastLocationStore: AnyObject, Sendable {
    var location: LocationInfo? { get set }
}

public final class UserDefaultsLastLocationStore: LastLocationStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        defaults: UserDefaults = .standard,
        key: String = "lastLocation"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public var location: LocationInfo? {
        get {
            guard let data = defaults.data(forKey: key) else { return nil }
            return try? decoder.decode(LocationInfo.self, from: data)
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: key)
                return
            }
            guard let data = try? encoder.encode(newValue) else { return }
            defaults.set(data, forKey: key)
        }
    }
}

public final class InMemoryLastLocationStore: LastLocationStore, @unchecked Sendable {
    public var location: LocationInfo?

    public init(location: LocationInfo? = nil) {
        self.location = location
    }
}

public enum ListCurrentLocationResolver {
    public static func initialLocation(cached: LocationInfo?) -> LocationInfo? {
        cached
    }
}
