import Foundation
import CoreModels

/// Mirrors `CoreMotionService`'s baseline-subtract + auto-rebase logic, but
/// applied to tilt angles derived from the gravity vector instead of the
/// CoreMotion Euler attitude. Drives the debug screen's `.gravity` 2D dot.
///
/// The math: for a gravity unit vector `g` in device frame (face-up rest:
/// `g ≈ (0, 0, -1)`), the device's tilt around its x-axis is
/// `atan2(g.y, -g.z)` (forward/back) and around its y-axis is
/// `atan2(g.x, -g.z)` (left/right). Both are continuous through every
/// orientation including past-vertical and upside-down — no Euler
/// singularity. Range is `(-π, π]`; downstream rendering divides by π so
/// 90° tilt sits halfway between center and box edge, leaving room to keep
/// rotating to the actual edge at 180°.
///
/// Disposable — lives only as long as the debug screen does.
public final class GravityRebaser: @unchecked Sendable {

    /// Latest tilt angles in radians, post-baseline-subtract.
    public private(set) var relativePitch: Double = 0
    public private(set) var relativeRoll: Double = 0

    /// Effective baseline angles in radians (interpolated during rebase ease).
    public private(set) var baselinePitch: Double = 0
    public private(set) var baselineRoll: Double = 0

    /// True when a rebase ease-back is currently animating.
    public private(set) var isRebaseInProgress: Bool = false
    /// `0...1` progress through the active rebase, else `0`.
    public private(set) var rebaseProgress: Double = 0
    /// Seconds since the user last moved past `movementThreshold`. Counts up;
    /// resets when fresh motion is detected. Used to drive the settle chip.
    public private(set) var secondsSinceSettleReset: TimeInterval = 0

    private var hasBaseline: Bool = false
    private var settleReferencePitch: Double = 0
    private var settleReferenceRoll: Double = 0
    private var settledSince: Date = Date()

    /// Unwrapped tilt angles, accumulated across frames. `atan2` itself wraps
    /// to (-π, π]; a phone tipped past upside-down would teleport the dot
    /// from one box edge to the other. We unwrap by tracking each axis's
    /// previous wrapped value and folding ±2π discontinuities out, so a
    /// continuous physical rotation maps to a continuous angle that just
    /// keeps growing — `position(...)` then clamps to the edge of the box.
    private var unwrappedPitch: Double = 0
    private var unwrappedRoll: Double = 0
    private var lastWrappedPitch: Double?
    private var lastWrappedRoll: Double?

    private var rebaseStart: Date?
    private var rebaseFromPitch: Double = 0
    private var rebaseFromRoll: Double = 0
    private var rebaseTargetPitch: Double = 0
    private var rebaseTargetRoll: Double = 0

    private let rebaseTransitionDuration: TimeInterval = 1.0

    public init() {}

    public func process(sample: MotionDebugSample, now: Date) {
        let g = sample.gravity
        let wrappedPitch = atan2(g.y, -g.z)
        let wrappedRoll = atan2(g.x, -g.z)

        unwrappedPitch = unwrap(current: wrappedPitch, previous: lastWrappedPitch, accumulated: unwrappedPitch)
        unwrappedRoll = unwrap(current: wrappedRoll, previous: lastWrappedRoll, accumulated: unwrappedRoll)
        lastWrappedPitch = wrappedPitch
        lastWrappedRoll = wrappedRoll

        if !hasBaseline {
            baselinePitch = unwrappedPitch
            baselineRoll = unwrappedRoll
            hasBaseline = true
            settledSince = now
            settleReferencePitch = 0
            settleReferenceRoll = 0
        }

        stepRebase(now: now, rawPitch: unwrappedPitch, rawRoll: unwrappedRoll)

        let relP = unwrappedPitch - baselinePitch
        let relR = unwrappedRoll - baselineRoll

        if rebaseStart == nil {
            let tuning = MotionTuning.shared
            let delta = max(abs(relP - settleReferencePitch), abs(relR - settleReferenceRoll))
            if delta > tuning.zeroPointMovementThresholdRadians {
                settleReferencePitch = relP
                settleReferenceRoll = relR
                settledSince = now
            } else if now.timeIntervalSince(settledSince) >= tuning.zeroPointSettleDuration {
                rebaseStart = now
                rebaseFromPitch = baselinePitch
                rebaseFromRoll = baselineRoll
                rebaseTargetPitch = unwrappedPitch
                rebaseTargetRoll = unwrappedRoll
            }
        }

        relativePitch = relP
        relativeRoll = relR
        secondsSinceSettleReset = now.timeIntervalSince(settledSince)
        isRebaseInProgress = rebaseStart != nil
        if let start = rebaseStart {
            rebaseProgress = min(1, max(0, now.timeIntervalSince(start) / rebaseTransitionDuration))
        } else {
            rebaseProgress = 0
        }
    }

    /// Standard angle-unwrapping: any per-frame jump > π is a wrap, fold it
    /// out by adjusting the accumulated value. Bounded by physical angular
    /// velocity — a real phone won't rotate >180° in a single 60 Hz tick.
    private func unwrap(current: Double, previous: Double?, accumulated: Double) -> Double {
        guard let previous else { return current }
        var delta = current - previous
        if delta > .pi { delta -= 2 * .pi }
        else if delta < -.pi { delta += 2 * .pi }
        return accumulated + delta
    }

    private func stepRebase(now: Date, rawPitch: Double, rawRoll: Double) {
        guard let start = rebaseStart else { return }
        let elapsed = now.timeIntervalSince(start)
        if elapsed >= rebaseTransitionDuration {
            baselinePitch = rebaseTargetPitch
            baselineRoll = rebaseTargetRoll
            rebaseStart = nil
            settleReferencePitch = 0
            settleReferenceRoll = 0
            settledSince = now
            return
        }
        let t = elapsed / rebaseTransitionDuration
        let eased = 0.5 - 0.5 * cos(t * .pi)
        baselinePitch = rebaseFromPitch + (rebaseTargetPitch - rebaseFromPitch) * eased
        baselineRoll = rebaseFromRoll + (rebaseTargetRoll - rebaseFromRoll) * eased
    }
}
