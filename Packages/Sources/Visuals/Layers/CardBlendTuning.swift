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
        public static let hideBackdrop: Bool = false
        public static let reverseDepthOrder: Bool = false
    }

    private enum Key {
        static let depthScale = "CardBlendTuning.depthScale"
        static let hideBackdrop = "CardBlendTuning.hideBackdrop"
        static let reverseDepthOrder = "CardBlendTuning.reverseDepthOrder"
    }

    public var depthScale: Double {
        didSet { defaults.set(depthScale, forKey: Key.depthScale) }
    }

    /// When true, the card backdrop (gradient + guilloche + silhouette +
    /// photo/blend) is omitted from both the rendered card and the sample
    /// closure passed to `CardTextLayer`, so the text layer composes against
    /// a transparent scene. Developer-only; defaults to off.
    public var hideBackdrop: Bool {
        didSet { defaults.set(hideBackdrop, forKey: Key.hideBackdrop) }
    }

    /// Flips the depth stack globally so layers that were anchored become the
    /// most mobile foreground layers, and vice versa. Developer-only; defaults
    /// to the original ordering.
    public var reverseDepthOrder: Bool {
        didSet { defaults.set(reverseDepthOrder, forKey: Key.reverseDepthOrder) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.depthScale = Self.read(defaults, Key.depthScale, fallback: Defaults.depthScale)
        self.hideBackdrop = Self.readBool(defaults, Key.hideBackdrop, fallback: Defaults.hideBackdrop)
        self.reverseDepthOrder = Self.readBool(defaults, Key.reverseDepthOrder, fallback: Defaults.reverseDepthOrder)
    }

    public func reset() {
        depthScale = Defaults.depthScale
        hideBackdrop = Defaults.hideBackdrop
        reverseDepthOrder = Defaults.reverseDepthOrder
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }

    private static func readBool(_ defaults: UserDefaults, _ key: String, fallback: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }
}
