import SwiftUI
import CoreModels

/// Runtime-tunable parameters for `HologramText`, exposed by the
/// developer-settings panel. Shipped defaults mirror the static constants
/// on `HologramText` (see `hologramTextTuningConstantsMatchSpec`).
///
/// `HologramText` observes `HologramTuning.shared`, so moving a slider
/// updates every instance on screen (card names + empty-state CTA) live.
/// Values persist across launches via `UserDefaults`.
@Observable
@MainActor
public final class HologramTuning {

    public static let shared = HologramTuning()

    public enum Defaults {
        public static let backdropBlurOpacity: Double = VisualDeveloperSettingsDefaults.hologram.backdropBlurOpacity
        public static let whiteFillOpacity: Double = VisualDeveloperSettingsDefaults.hologram.whiteFillOpacity
        public static let lightenOpacity: Double = VisualDeveloperSettingsDefaults.hologram.lightenOpacity
        public static let luminosityOpacity: Double = VisualDeveloperSettingsDefaults.hologram.luminosityOpacity
        public static let translationScaleX: Double = VisualDeveloperSettingsDefaults.hologram.translationScaleX
        public static let translationScaleY: Double = VisualDeveloperSettingsDefaults.hologram.translationScaleY
        public static let rotationDegrees: Double = VisualDeveloperSettingsDefaults.hologram.rotationDegrees
    }

    private enum Key {
        static let backdropBlurOpacity = "HologramTuning.backdropBlurOpacity"
        static let whiteFillOpacity = "HologramTuning.whiteFillOpacity"
        static let lightenOpacity = "HologramTuning.lightenOpacity"
        static let luminosityOpacity = "HologramTuning.luminosityOpacity"
        static let translationScaleX = "HologramTuning.translationScaleX"
        static let translationScaleY = "HologramTuning.translationScaleY"
        static let rotationDegrees = "HologramTuning.rotationDegrees"
    }

    public var backdropBlurOpacity: Double {
        didSet { defaults.set(backdropBlurOpacity, forKey: Key.backdropBlurOpacity) }
    }
    public var whiteFillOpacity: Double {
        didSet { defaults.set(whiteFillOpacity, forKey: Key.whiteFillOpacity) }
    }
    public var lightenOpacity: Double {
        didSet { defaults.set(lightenOpacity, forKey: Key.lightenOpacity) }
    }
    public var luminosityOpacity: Double {
        didSet { defaults.set(luminosityOpacity, forKey: Key.luminosityOpacity) }
    }
    public var translationScaleX: Double {
        didSet { defaults.set(translationScaleX, forKey: Key.translationScaleX) }
    }
    public var translationScaleY: Double {
        didSet { defaults.set(translationScaleY, forKey: Key.translationScaleY) }
    }
    public var rotationDegrees: Double {
        didSet { defaults.set(rotationDegrees, forKey: Key.rotationDegrees) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.backdropBlurOpacity = Self.read(defaults, Key.backdropBlurOpacity, fallback: Defaults.backdropBlurOpacity)
        self.whiteFillOpacity = Self.read(defaults, Key.whiteFillOpacity, fallback: Defaults.whiteFillOpacity)
        self.lightenOpacity = Self.read(defaults, Key.lightenOpacity, fallback: Defaults.lightenOpacity)
        self.luminosityOpacity = Self.read(defaults, Key.luminosityOpacity, fallback: Defaults.luminosityOpacity)
        self.translationScaleX = Self.read(defaults, Key.translationScaleX, fallback: Defaults.translationScaleX)
        self.translationScaleY = Self.read(defaults, Key.translationScaleY, fallback: Defaults.translationScaleY)
        self.rotationDegrees = Self.read(defaults, Key.rotationDegrees, fallback: Defaults.rotationDegrees)
    }

    public func reset() {
        backdropBlurOpacity = Defaults.backdropBlurOpacity
        whiteFillOpacity = Defaults.whiteFillOpacity
        lightenOpacity = Defaults.lightenOpacity
        luminosityOpacity = Defaults.luminosityOpacity
        translationScaleX = Defaults.translationScaleX
        translationScaleY = Defaults.translationScaleY
        rotationDegrees = Defaults.rotationDegrees
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}
