import SwiftUI

/// Runtime-tunable aspect ratio (height ÷ width) for the medium-sized
/// `CardView` shown in the tapped-card modal. Range spans from the list-row
/// shape (~0.57 — short and wide) up to 1.6 (tall and narrow), with a 1:1
/// notch as the natural default.
///
/// `TappedCardModalScene` observes `MediumCardSizeTuning.shared`, so dragging
/// the slider in Developer Settings updates the running view live. Persists
/// across launches via `UserDefaults`.
@Observable
@MainActor
public final class MediumCardSizeTuning {

    public static let shared = MediumCardSizeTuning()

    public enum Defaults {
        public static let aspectRatio: Double = 1.0
        /// Matches the list row's 211pt height against the iPhone 17 row width
        /// (402pt screen − 32pt horizontal padding = 370pt). Used as the slider
        /// minimum so the user can pull the medium card down to the same shape
        /// it has in the list.
        public static let minAspectRatio: Double = 211.0 / 370.0
        public static let maxAspectRatio: Double = 1.6
    }

    private enum Key {
        static let aspectRatio = "MediumCardSizeTuning.aspectRatio"
    }

    public var aspectRatio: Double {
        didSet { defaults.set(aspectRatio, forKey: Key.aspectRatio) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.aspectRatio = Self.read(
            defaults,
            Key.aspectRatio,
            fallback: Defaults.aspectRatio
        )
    }

    public func reset() {
        aspectRatio = Defaults.aspectRatio
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}
