import SwiftUI

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
        public static let moonPhaseLayer: Int = 12
        public static let zodiacGlyphLayer: Int = 4
        public static let zodiacConstellationLayer: Int = 15
        public static let perspectiveAmount: Double = 1.0
        public static let perspectiveAmountMin: Double = 0.0
        public static let perspectiveAmountMax: Double = 3.0
    }

    private enum Key {
        static let moonPhaseLayer = "CardElementDepthTuning.moonPhaseLayer"
        static let zodiacGlyphLayer = "CardElementDepthTuning.zodiacGlyphLayer"
        static let zodiacConstellationLayer = "CardElementDepthTuning.zodiacConstellationLayer"
        static let perspectiveAmount = "CardElementDepthTuning.perspectiveAmount"
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

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.moonPhaseLayer = Self.read(defaults, Key.moonPhaseLayer, fallback: Defaults.moonPhaseLayer)
        self.zodiacGlyphLayer = Self.read(defaults, Key.zodiacGlyphLayer, fallback: Defaults.zodiacGlyphLayer)
        self.zodiacConstellationLayer = Self.read(defaults, Key.zodiacConstellationLayer, fallback: Defaults.zodiacConstellationLayer)
        self.perspectiveAmount = Self.read(defaults, Key.perspectiveAmount, fallback: Defaults.perspectiveAmount)
    }

    public func reset() {
        moonPhaseLayer = Defaults.moonPhaseLayer
        zodiacGlyphLayer = Defaults.zodiacGlyphLayer
        zodiacConstellationLayer = Defaults.zodiacConstellationLayer
        perspectiveAmount = Defaults.perspectiveAmount
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Int) -> Int {
        defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}
