import SwiftUI

/// Runtime-tunable parameters for `GradientLayer`'s transfusion effect —
/// how sharply the second (rotated) gradient opacity tracks device roll.
/// Exposed by the developer-settings panel.
///
/// `GradientLayer` observes `GradientLayerTuning.shared`, so moving the
/// slider updates every instance on screen live. Persists across launches
/// via `UserDefaults`.
@Observable
@MainActor
public final class GradientLayerTuning {

    public static let shared = GradientLayerTuning()

    public enum Defaults {
        /// Multiplier applied to `attitude.roll` before mapping into [0, 1]
        /// opacity. `1.0` is the spec default (linear `(roll + 1) / 2`).
        /// Higher values flip the transfusion faster around roll = 0;
        /// `0` pins the layer at 50%.
        public static let motionSensitivity: Double = 1.0
    }

    private enum Key {
        static let motionSensitivity = "GradientLayerTuning.motionSensitivity"
    }

    public var motionSensitivity: Double {
        didSet { defaults.set(motionSensitivity, forKey: Key.motionSensitivity) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.motionSensitivity = Self.read(
            defaults, Key.motionSensitivity, fallback: Defaults.motionSensitivity
        )
    }

    public func reset() {
        motionSensitivity = Defaults.motionSensitivity
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}
