import SwiftUI

/// Runtime-tunable parameters for `GuillocheRotationLayer`'s gyro-driven
/// spin. Exposed by the developer-settings panel.
///
/// `GuillocheRotationLayer` observes `GuillocheRotationTuning.shared`, so
/// moving the slider updates every instance on screen (empty-state hero
/// filigree + per-card letter filigree) live. Persists across launches via
/// `UserDefaults`.
@Observable
@MainActor
public final class GuillocheRotationTuning {

    public static let shared = GuillocheRotationTuning()

    public enum Defaults {
        /// Max rotation (degrees) the empty-state hero filigree spins when a
        /// single axis is at full tilt. See `rotationAngle(for:)` for the sign
        /// convention.
        public static let emptyStateRotationDegrees: Double = 90
        /// Same control, card-backdrop usage. Split so card + hero can be
        /// dialed in independently — the card's smaller canvas wants a
        /// subtler amount than the hero.
        public static let cardRotationDegrees: Double = 45
        /// Stroke opacity for the card-backdrop swirl filigree.
        public static let cardOpacity: Double = 0.2
        /// Stroke opacity for the empty-state hero swirl filigree.
        public static let emptyStateOpacity: Double = 0.3
        /// Slider ceiling shared by both opacity controls in the dev panel.
        public static let opacityMax: Double = 0.4
    }

    private enum Key {
        static let emptyStateRotationDegrees = "GuillocheRotationTuning.emptyStateRotationDegrees"
        static let cardRotationDegrees = "GuillocheRotationTuning.cardRotationDegrees"
        static let cardOpacity = "GuillocheRotationTuning.cardOpacity"
        static let emptyStateOpacity = "GuillocheRotationTuning.emptyStateOpacity"
    }

    public var emptyStateRotationDegrees: Double {
        didSet { defaults.set(emptyStateRotationDegrees, forKey: Key.emptyStateRotationDegrees) }
    }

    public var cardRotationDegrees: Double {
        didSet { defaults.set(cardRotationDegrees, forKey: Key.cardRotationDegrees) }
    }

    public var cardOpacity: Double {
        didSet { defaults.set(cardOpacity, forKey: Key.cardOpacity) }
    }

    public var emptyStateOpacity: Double {
        didSet { defaults.set(emptyStateOpacity, forKey: Key.emptyStateOpacity) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.emptyStateRotationDegrees = Self.read(
            defaults, Key.emptyStateRotationDegrees, fallback: Defaults.emptyStateRotationDegrees
        )
        self.cardRotationDegrees = Self.read(
            defaults, Key.cardRotationDegrees, fallback: Defaults.cardRotationDegrees
        )
        self.cardOpacity = Self.read(
            defaults, Key.cardOpacity, fallback: Defaults.cardOpacity
        )
        self.emptyStateOpacity = Self.read(
            defaults, Key.emptyStateOpacity, fallback: Defaults.emptyStateOpacity
        )
    }

    public func reset() {
        emptyStateRotationDegrees = Defaults.emptyStateRotationDegrees
        cardRotationDegrees = Defaults.cardRotationDegrees
        cardOpacity = Defaults.cardOpacity
        emptyStateOpacity = Defaults.emptyStateOpacity
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}
