import SwiftUI
import CoreModels

/// Per-element depth-layer assignment for ornaments composited on top of the
/// card backdrop (moon phase, zodiac glyph, zodiac constellation). Each
/// element's translation under tilt uses the same perspective projection as the
/// blend stack, so ornaments read as if they're sitting on a specific path of
/// the guilloche.
///
/// Layer 0 = anchored (no movement), layer 14 = deepest blend path / rotation
/// guilloche level, layer 15 = one step beyond the deepest blend path. Sliders
/// in the dev panel are stepped to integer positions.
@Observable
@MainActor
public final class CardElementDepthTuning {

    public static let shared = CardElementDepthTuning()

    public static let layerRange: ClosedRange<Int> = 0...15

    public enum Defaults {
        public static let moonPhaseLayer: Int = VisualDeveloperSettingsDefaults.elementDepth.moonPhaseLayer
        public static let zodiacGlyphLayer: Int = VisualDeveloperSettingsDefaults.elementDepth.zodiacGlyphLayer
        public static let zodiacConstellationLayer: Int = VisualDeveloperSettingsDefaults.elementDepth.zodiacConstellationLayer
        public static let perspectiveAmount: Double = VisualDeveloperSettingsDefaults.elementDepth.perspectiveAmount
        public static let perspectiveAmountMin: Double = 0.0
        public static let perspectiveAmountMax: Double = 3.0
        public static let isSkewEnabled: Bool = VisualDeveloperSettingsDefaults.elementDepth.isSkewEnabled
        public static let skewAmount: Double = VisualDeveloperSettingsDefaults.elementDepth.skewAmount
        public static let skewAmountMin: Double = 0.0
        public static let skewAmountMax: Double = 0.2
    }

    private enum Key {
        static let moonPhaseLayer = "CardElementDepthTuning.moonPhaseLayer"
        static let zodiacGlyphLayer = "CardElementDepthTuning.zodiacGlyphLayer"
        static let zodiacConstellationLayer = "CardElementDepthTuning.zodiacConstellationLayer"
        static let perspectiveAmount = "CardElementDepthTuning.perspectiveAmount"
        static let isSkewEnabled = "CardElementDepthTuning.isSkewEnabled"
        static let skewAmount = "CardElementDepthTuning.skewAmount"
    }

    public var moonPhaseLayer: Int {
        didSet { defaults.set(moonPhaseLayer, forKey: Key.moonPhaseLayer) }
    }

    public var zodiacGlyphLayer: Int {
        didSet { defaults.set(zodiacGlyphLayer, forKey: Key.zodiacGlyphLayer) }
    }

    public var zodiacConstellationLayer: Int {
        didSet { defaults.set(zodiacConstellationLayer, forKey: Key.zodiacConstellationLayer) }
    }

    public var perspectiveAmount: Double {
        didSet { defaults.set(perspectiveAmount, forKey: Key.perspectiveAmount) }
    }

    public var isSkewEnabled: Bool {
        didSet { defaults.set(isSkewEnabled, forKey: Key.isSkewEnabled) }
    }

    public var skewAmount: Double {
        didSet { defaults.set(skewAmount, forKey: Key.skewAmount) }
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.moonPhaseLayer = Self.read(defaults, Key.moonPhaseLayer, fallback: Defaults.moonPhaseLayer)
        self.zodiacGlyphLayer = Self.read(defaults, Key.zodiacGlyphLayer, fallback: Defaults.zodiacGlyphLayer)
        self.zodiacConstellationLayer = Self.read(defaults, Key.zodiacConstellationLayer, fallback: Defaults.zodiacConstellationLayer)
        self.perspectiveAmount = Self.read(defaults, Key.perspectiveAmount, fallback: Defaults.perspectiveAmount)
        self.isSkewEnabled = Self.read(defaults, Key.isSkewEnabled, fallback: Defaults.isSkewEnabled)
        self.skewAmount = Self.read(defaults, Key.skewAmount, fallback: Defaults.skewAmount)
    }

    public func reset() {
        moonPhaseLayer = Defaults.moonPhaseLayer
        zodiacGlyphLayer = Defaults.zodiacGlyphLayer
        zodiacConstellationLayer = Defaults.zodiacConstellationLayer
        perspectiveAmount = Defaults.perspectiveAmount
        isSkewEnabled = Defaults.isSkewEnabled
        skewAmount = Defaults.skewAmount
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Int) -> Int {
        defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }
}
