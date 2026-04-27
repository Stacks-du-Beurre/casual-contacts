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

    /// Degrees of rotation from baseline (around either device axis) that
    /// drive the production `attitude` stream's pitch/roll to ±1. Smaller =
    /// more sensitive (less physical motion fills the visual range), larger
    /// = more tilt required.
    public var relativeFullScaleDegrees: Double = 45

    public var relativeFullScaleRadians: Double {
        relativeFullScaleDegrees * .pi / 180
    }

    private init() {}
}
