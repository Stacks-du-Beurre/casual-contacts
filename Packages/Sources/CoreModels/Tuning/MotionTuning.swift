import Foundation
import Observation

/// Tunable knobs for the production motion pipeline. `@Observable` so SwiftUI
/// developer surfaces can bind to it, but reads from `CoreMotionService` (off
/// the main actor on the CoreMotion callback queue) are simple value reads —
/// `Double` writes/reads are atomic enough on Apple silicon for a tuning
/// knob, and the tracker only fires SwiftUI invalidations for views that
/// actually read the property in their body.
@Observable
public final class MotionTuning: @unchecked Sendable {

    public static let shared = MotionTuning()

    public enum Defaults {
        public static let relativeFullScaleDegrees: Double = 45
        public static let saveButtonGradientGain: Double = 2.5
        public static let zeroPointSettleDuration: TimeInterval = 2.0
        public static let zeroPointSettleDurationMin: TimeInterval = 0.5
        public static let zeroPointSettleDurationMax: TimeInterval = 4.0
        public static let zeroPointMovementThresholdRadians: Double = 0.08
    }

    private enum Key {
        static let relativeFullScaleDegrees = "MotionTuning.relativeFullScaleDegrees"
        static let saveButtonGradientGain = "MotionTuning.saveButtonGradientGain"
        static let zeroPointSettleDuration = "MotionTuning.zeroPointSettleDuration"
    }

    /// Degrees of rotation from baseline (around either device axis) that
    /// drive the production `attitude` stream's pitch/roll to ±1. Smaller =
    /// more sensitive (less physical motion fills the visual range), larger
    /// = more tilt required.
    public var relativeFullScaleDegrees: Double {
        didSet { defaults.set(relativeFullScaleDegrees, forKey: Key.relativeFullScaleDegrees) }
    }

    public var relativeFullScaleRadians: Double {
        relativeFullScaleDegrees * .pi / 180
    }

    /// Sensitivity multiplier applied to `attitude.roll` before the
    /// `GradientLayer` opacity curve in the create/update flow's SaveButton.
    /// `1.0` matches the global pipeline full-scale (button reaches its
    /// endpoint when the phone is rotated a full ±`relativeFullScaleDegrees`).
    /// Higher values let the smaller, button-sized gradient swap noticeably
    /// at much subtler tilts than the card backdrop's full visual range.
    public var saveButtonGradientGain: Double {
        didSet { defaults.set(saveButtonGradientGain, forKey: Key.saveButtonGradientGain) }
    }

    /// Seconds of low movement before the motion pipeline eases the current
    /// device pose back to zero. Developer-tunable so testing can balance
    /// responsiveness against accidental recentering.
    public var zeroPointSettleDuration: TimeInterval {
        didSet { defaults.set(zeroPointSettleDuration, forKey: Key.zeroPointSettleDuration) }
    }

    /// Small movement allowance while counting toward a zero-point reset.
    /// About 4.5 degrees: enough to tolerate hand tremor, not active tilt.
    public let zeroPointMovementThresholdRadians: Double

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.relativeFullScaleDegrees = Self.read(
            defaults,
            Key.relativeFullScaleDegrees,
            fallback: Defaults.relativeFullScaleDegrees
        )
        self.saveButtonGradientGain = Self.read(
            defaults,
            Key.saveButtonGradientGain,
            fallback: Defaults.saveButtonGradientGain
        )
        self.zeroPointSettleDuration = Self.read(
            defaults,
            Key.zeroPointSettleDuration,
            fallback: Defaults.zeroPointSettleDuration
        )
        self.zeroPointMovementThresholdRadians = Defaults.zeroPointMovementThresholdRadians
    }

    public func reset() {
        relativeFullScaleDegrees = Defaults.relativeFullScaleDegrees
        saveButtonGradientGain = Defaults.saveButtonGradientGain
        zeroPointSettleDuration = Defaults.zeroPointSettleDuration
    }

    private static func read(_ defaults: UserDefaults, _ key: String, fallback: Double) -> Double {
        defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
    }
}
