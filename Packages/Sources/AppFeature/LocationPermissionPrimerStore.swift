import Foundation

public enum LocationPermissionPrimerDecision: String, Sendable, Equatable {
    case notAnswered
    case accepted
    case declined
}

public protocol LocationPermissionPrimerStore: AnyObject {
    var decision: LocationPermissionPrimerDecision { get set }
}

public final class UserDefaultsLocationPermissionPrimerStore: LocationPermissionPrimerStore {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "locationPermissionPrimerDecision"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public var decision: LocationPermissionPrimerDecision {
        get {
            guard let raw = defaults.string(forKey: key),
                  let decision = LocationPermissionPrimerDecision(rawValue: raw) else {
                return .notAnswered
            }
            return decision
        }
        set {
            defaults.set(newValue.rawValue, forKey: key)
        }
    }
}

public final class InMemoryLocationPermissionPrimerStore: LocationPermissionPrimerStore {
    public var decision: LocationPermissionPrimerDecision

    public init(decision: LocationPermissionPrimerDecision = .notAnswered) {
        self.decision = decision
    }
}
