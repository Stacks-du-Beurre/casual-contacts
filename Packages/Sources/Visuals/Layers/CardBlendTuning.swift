import SwiftUI

/// Runtime-tunable parameters for the card's `GuillocheBlendLayer` parallax,
/// exposed by the developer-settings panel.
///
/// `CardView` observes `CardBlendTuning.shared`, so moving the slider updates
/// the running view live. Persists across launches via `UserDefaults`.
@Observable
@MainActor
public final class CardBlendTuning {

    public static let shared = CardBlendTuning()

    public enum Defaults {
        /// Card parallax depth. Half the empty-state hero's `10.0` so rows in a
        /// list don't read as chaotic when the device tilts.
        public static let depthScale: Double = 5.0
    }

    private enum Key {
        static let depthScale = "CardBlendTuning.depthScale"
    }

    public var depthScale: Double {
        didSet { defaults.set(depthScale, forKey: Key.depthScale) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.depthScale = Self.read(defaults, Key.depthScale, fallback: Defaults.depthScale)
    }

    public func reset() {
        depthScale = Defaults.depthScale
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}
