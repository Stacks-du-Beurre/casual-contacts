import SwiftUI

/// Per-element depth-layer assignment for ornaments composited on top of the
/// card backdrop (moon phase, zodiac glyph, zodiac constellation). Each
/// element's translation under tilt = `layer × cardBlendDepthScale × attitude`,
/// matching the math the blend stack uses internally so ornaments read as if
/// they're sitting on a specific path of the guilloche.
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
    }

    private enum Key {
        static let moonPhaseLayer = "CardElementDepthTuning.moonPhaseLayer"
        static let zodiacGlyphLayer = "CardElementDepthTuning.zodiacGlyphLayer"
        static let zodiacConstellationLayer = "CardElementDepthTuning.zodiacConstellationLayer"
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

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.moonPhaseLayer = Self.read(defaults, Key.moonPhaseLayer, fallback: Defaults.moonPhaseLayer)
        self.zodiacGlyphLayer = Self.read(defaults, Key.zodiacGlyphLayer, fallback: Defaults.zodiacGlyphLayer)
        self.zodiacConstellationLayer = Self.read(defaults, Key.zodiacConstellationLayer, fallback: Defaults.zodiacConstellationLayer)
    }

    public func reset() {
        moonPhaseLayer = Defaults.moonPhaseLayer
        zodiacGlyphLayer = Defaults.zodiacGlyphLayer
        zodiacConstellationLayer = Defaults.zodiacConstellationLayer
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Int) -> Int {
        defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
    }
}
