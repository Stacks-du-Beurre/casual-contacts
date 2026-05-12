import SwiftUI
import CoreModels

/// Runtime-tunable parameters for `PhotoLayer` — focus shift + rendered
/// opacity — exposed by the developer-settings panel.
///
/// `PhotoLayer` observes `PhotoFocusTuning.shared`, so moving a slider
/// updates the running view live. Persists across launches via `UserDefaults`.
@Observable
@MainActor
public final class PhotoFocusTuning {

    public static let shared = PhotoFocusTuning()

    public enum Defaults {
        /// Amount of additional zoom applied to the photo beyond scaledToFill.
        /// 0 = scaledToFill (max zoom-out — photo still fully covers the
        /// card); 1 = `maxZoomMultiplier × scaledToFill` (max zoom-in,
        /// tightly framed on the face). Defaults at 0 so the photo renders
        /// at the widest possible framing by default.
        public static let faceZoom: Double = VisualDeveloperSettingsDefaults.zodiacAndPhoto.photoFaceZoom

        /// Opacity of the luminosity-blended photo over the card backdrop.
        public static let opacity: Double = VisualDeveloperSettingsDefaults.zodiacAndPhoto.photoOpacity
    }

    /// Slider value 1.0 maps to this multiplier on scaledToFill, so the face
    /// can be zoomed in up to 2.5× beyond the baseline fill scale.
    public static let maxZoomMultiplier: Double = 2.5

    private enum Key {
        static let faceZoom = "PhotoFocusTuning.faceZoom"
        static let opacity = "PhotoFocusTuning.opacity"
    }

    public var faceZoom: Double {
        didSet { defaults.set(faceZoom, forKey: Key.faceZoom) }
    }

    public var opacity: Double {
        didSet { defaults.set(opacity, forKey: Key.opacity) }
    }

    /// Effective multiplier on scaledToFill. 1.0 = fill, higher = zoomed in.
    public var zoomMultiplier: Double {
        1.0 + max(0, min(1, faceZoom)) * (Self.maxZoomMultiplier - 1.0)
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.faceZoom = Self.read(defaults, Key.faceZoom, fallback: Defaults.faceZoom)
        self.opacity = Self.read(defaults, Key.opacity, fallback: Defaults.opacity)
    }

    public func reset() {
        faceZoom = Defaults.faceZoom
        opacity = Defaults.opacity
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}
