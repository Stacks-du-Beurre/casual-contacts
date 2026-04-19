import SwiftUI

/// Runtime-tunable parameters for the holographic chromatic fill inside
/// `HolographicZodiac`. The fill is a single hologram texture masked by the
/// zodiac silhouette; only its gyro-driven rotation is tunable. Values
/// persist across launches via `UserDefaults` and can be adjusted in the
/// developer-settings panel.
@Observable
@MainActor
public final class ZodiacHologramTuning {

    public static let shared = ZodiacHologramTuning()

    public enum Defaults {
        public static let rotationDegrees: Double = 300
    }

    private enum Key {
        static let rotationDegrees = "ZodiacHologramTuning.rotationDegrees"
    }

    public var rotationDegrees: Double {
        didSet { defaults.set(rotationDegrees, forKey: Key.rotationDegrees) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.rotationDegrees = Self.read(defaults, Key.rotationDegrees, fallback: Defaults.rotationDegrees)
    }

    public func reset() {
        rotationDegrees = Defaults.rotationDegrees
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}
