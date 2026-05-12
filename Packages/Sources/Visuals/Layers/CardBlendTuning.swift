import SwiftUI
import CoreModels

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
        public static let depthScale: Double = VisualDeveloperSettingsDefaults.cardBackdrop.depthScale
        public static let hideBackdrop: Bool = VisualDeveloperSettingsDefaults.cardBackdrop.hideBackdrop
        public static let reverseDepthOrder: Bool = VisualDeveloperSettingsDefaults.cardBackdrop.reverseDepthOrder
        public static let reverseMotionDirection: Bool = VisualDeveloperSettingsDefaults.cardBackdrop.reverseMotionDirection
        public static let rotationGuillocheMovesInsteadOfRotates: Bool = VisualDeveloperSettingsDefaults.cardBackdrop.rotationGuillocheMovesInsteadOfRotates
        public static let guillocheMovementScaleX: Double = VisualDeveloperSettingsDefaults.cardBackdrop.guillocheMovementScaleX
        public static let guillocheMovementScaleY: Double = VisualDeveloperSettingsDefaults.cardBackdrop.guillocheMovementScaleY
    }

    private enum Key {
        static let depthScale = "CardBlendTuning.depthScale"
        static let hideBackdrop = "CardBlendTuning.hideBackdrop"
        static let reverseDepthOrder = "CardBlendTuning.reverseDepthOrder"
        static let reverseMotionDirection = "CardBlendTuning.reverseMotionDirection"
        static let rotationGuillocheMovesInsteadOfRotates = "CardBlendTuning.rotationGuillocheMovesInsteadOfRotates"
        static let guillocheMovementScaleX = "CardBlendTuning.guillocheMovementScaleX"
        static let guillocheMovementScaleY = "CardBlendTuning.guillocheMovementScaleY"
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

    /// Flips x/y motion direction while keeping the depth ordering unchanged.
    /// This is shared by guilloche/depth offsets and the frosted location-pill
    /// blur so developer testing can compare both directions coherently.
    public var reverseMotionDirection: Bool {
        didSet { defaults.set(reverseMotionDirection, forKey: Key.reverseMotionDirection) }
    }

    /// Chooses the rotation-guilloche motion mode. Defaults to rotating in
    /// place; when enabled, the layer follows the x/y depth offset and stops
    /// applying its attitude-driven rotation.
    public var rotationGuillocheMovesInsteadOfRotates: Bool {
        didSet {
            defaults.set(
                rotationGuillocheMovesInsteadOfRotates,
                forKey: Key.rotationGuillocheMovesInsteadOfRotates
            )
        }
    }

    /// Multiplies the guilloche stack's roll-driven x translation after depth
    /// projection. Defaults below full strength to keep card motion restrained.
    public var guillocheMovementScaleX: Double {
        didSet { defaults.set(guillocheMovementScaleX, forKey: Key.guillocheMovementScaleX) }
    }

    /// Multiplies the guilloche stack's pitch-driven y translation after depth
    /// projection. Defaults below full strength to keep card motion restrained.
    public var guillocheMovementScaleY: Double {
        didSet { defaults.set(guillocheMovementScaleY, forKey: Key.guillocheMovementScaleY) }
    }

    public var motionDirectionMultiplier: Double {
        reverseMotionDirection ? -1 : 1
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.depthScale = Self.read(defaults, Key.depthScale, fallback: Defaults.depthScale)
        self.hideBackdrop = Self.readBool(defaults, Key.hideBackdrop, fallback: Defaults.hideBackdrop)
        self.reverseDepthOrder = Self.readBool(defaults, Key.reverseDepthOrder, fallback: Defaults.reverseDepthOrder)
        self.reverseMotionDirection = Self.readBool(
            defaults,
            Key.reverseMotionDirection,
            fallback: Defaults.reverseMotionDirection
        )
        self.rotationGuillocheMovesInsteadOfRotates = Self.readBool(
            defaults,
            Key.rotationGuillocheMovesInsteadOfRotates,
            fallback: Defaults.rotationGuillocheMovesInsteadOfRotates
        )
        self.guillocheMovementScaleX = Self.read(
            defaults,
            Key.guillocheMovementScaleX,
            fallback: Defaults.guillocheMovementScaleX
        )
        self.guillocheMovementScaleY = Self.read(
            defaults,
            Key.guillocheMovementScaleY,
            fallback: Defaults.guillocheMovementScaleY
        )
    }

    public func reset() {
        depthScale = Defaults.depthScale
        hideBackdrop = Defaults.hideBackdrop
        reverseDepthOrder = Defaults.reverseDepthOrder
        reverseMotionDirection = Defaults.reverseMotionDirection
        rotationGuillocheMovesInsteadOfRotates = Defaults.rotationGuillocheMovesInsteadOfRotates
        guillocheMovementScaleX = Defaults.guillocheMovementScaleX
        guillocheMovementScaleY = Defaults.guillocheMovementScaleY
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }

    private static func readBool(_ defaults: UserDefaults, _ key: String, fallback: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }
}
