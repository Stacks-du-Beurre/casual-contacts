import SwiftUI

/// Runtime-tunable parameters for `EmptyStateGradientBackdrop`, exposed by
/// the developer-settings panel. Kept separate from `HologramTuning` because
/// the empty-state gradient drift is a distinct effect with its own range.
///
/// `EmptyStateGradientBackdrop` observes `EmptyStateGradientTuning.shared`,
/// so moving the slider updates the running view live. Persists across
/// launches via `UserDefaults`.
@Observable
@MainActor
public final class EmptyStateGradientTuning {

    public static let shared = EmptyStateGradientTuning()

    public enum Defaults {
        /// Fraction of the available horizontal slack the gradient reaches at
        /// full tilt. Slack is derived from the painting's natural aspect
        /// scaled-to-fill the viewport. `1.0` = the far edge of the painting
        /// touches the viewport edge at `|roll| == 1`; the gradient never
        /// pans past it.
        public static let edgeReach: Double = 1.0
    }

    private enum Key {
        static let edgeReach = "EmptyStateGradientTuning.edgeReach"
    }

    public var edgeReach: Double {
        didSet { defaults.set(edgeReach, forKey: Key.edgeReach) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.edgeReach = Self.read(defaults, Key.edgeReach, fallback: Defaults.edgeReach)
    }

    public func reset() {
        edgeReach = Defaults.edgeReach
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}
