import Foundation

/// Quaternion-delta-based rebaser that gives clean, gimbal-lock-free signals
/// for the two motions the production cards animate against:
///
/// - **Twist** — rotation around the device's long Y axis. Phone twisting
///   left/right around a vertical line drawn through screen center.
/// - **Pitch** — rotation around the device's short X axis. The top of the
///   phone tilting toward (or away from) the user.
///
/// Approach:
///   1. Capture baseline orientation as a quaternion `q_baseline` on the first
///      sample (and at each auto-rebase).
///   2. Per frame, compute `q_delta = q_baseline⁻¹ · q_current`. This is the
///      rotation from baseline to current, expressed in baseline-local
///      coordinates — its X component reads directly as "rotation around
///      baseline X axis", Y as "rotation around baseline Y axis", regardless
///      of where in world space the baseline pose sits.
///   3. Convert each component to a signed angle via `2 · atan2(qD.x, qD.w)`.
///      No singularities, no edge reversals. Linear angular response.
///   4. Auto-rebase: after `settleDuration` of stillness, slerp `q_baseline`
///      toward the current pose over `rebaseTransitionDuration` so the visual
///      eases back to center without snapping.
///
/// Output is in radians; consumers divide by a tunable full-scale angle to
/// get a unit-bounded signal. Lives in CoreModels so both `CoreMotionService`
/// (production) and the debug screen can share the same implementation.
public final class RelativeRotationRebaser: @unchecked Sendable {

    /// Signed rotation around the device's X-axis since baseline. Positive =
    /// top of phone tipping toward the user. Radians.
    public private(set) var relativePitch: Double = 0
    /// Signed rotation around the device's Y-axis since baseline. Positive =
    /// left edge dipping (phone twisting counterclockwise from user's POV).
    /// Radians.
    public private(set) var relativeTwist: Double = 0

    public private(set) var isRebaseInProgress: Bool = false
    public private(set) var rebaseProgress: Double = 0
    public private(set) var secondsSinceSettleReset: TimeInterval = 0

    /// Current effective baseline (post-rebase ease). Public so debug-screen
    /// trail rendering can recompute per-historical-sample relative angles
    /// against the same baseline as the live dot — most callers will use
    /// `angles(forQuaternion:)` instead.
    public private(set) var baselineQuat: Quaternion = .identity

    private var hasBaseline: Bool = false

    private var settleReferencePitch: Double = 0
    private var settleReferenceTwist: Double = 0
    private var settledSince: Date = Date()

    private var rebaseStart: Date?
    private var rebaseFromQuat: Quaternion = .identity
    private var rebaseTargetQuat: Quaternion = .identity

    private let movementThreshold: Double = 0.05  // radians, ~3°
    private let settleDuration: TimeInterval = 3.5
    private let rebaseTransitionDuration: TimeInterval = 1.0

    public init() {}

    /// Feed one inbound CoreMotion sample's quaternion. Updates
    /// `relativePitch`, `relativeTwist`, and the rebase / settle state.
    public func process(quaternion: SIMD4<Double>, now: Date) {
        let qRaw = Quaternion(
            x: quaternion.x,
            y: quaternion.y,
            z: quaternion.z,
            w: quaternion.w
        ).canonical

        if !hasBaseline {
            baselineQuat = qRaw
            hasBaseline = true
            settledSince = now
            settleReferencePitch = 0
            settleReferenceTwist = 0
        }

        stepRebase(now: now)

        let qDelta = (baselineQuat.conjugate * qRaw).canonical
        let pitch = 2 * atan2(qDelta.x, qDelta.w)
        let twist = 2 * atan2(qDelta.y, qDelta.w)

        if rebaseStart == nil {
            let movement = max(abs(pitch - settleReferencePitch), abs(twist - settleReferenceTwist))
            if movement > movementThreshold {
                settleReferencePitch = pitch
                settleReferenceTwist = twist
                settledSince = now
            } else if now.timeIntervalSince(settledSince) >= settleDuration {
                rebaseStart = now
                rebaseFromQuat = baselineQuat
                rebaseTargetQuat = qRaw
            }
        }

        relativePitch = pitch
        relativeTwist = twist
        secondsSinceSettleReset = now.timeIntervalSince(settledSince)
        isRebaseInProgress = rebaseStart != nil
        if let start = rebaseStart {
            rebaseProgress = min(1, max(0, now.timeIntervalSince(start) / rebaseTransitionDuration))
        } else {
            rebaseProgress = 0
        }
    }

    /// Per-historical-sample relative angles against the rebaser's current
    /// baseline. Lets renderers reconstruct a trail of past samples without
    /// the rebaser having to keep per-sample state.
    public func angles(forQuaternion quaternion: SIMD4<Double>) -> (pitch: Double, twist: Double) {
        let qRaw = Quaternion(
            x: quaternion.x,
            y: quaternion.y,
            z: quaternion.z,
            w: quaternion.w
        ).canonical
        let qDelta = (baselineQuat.conjugate * qRaw).canonical
        return (2 * atan2(qDelta.x, qDelta.w), 2 * atan2(qDelta.y, qDelta.w))
    }

    private func stepRebase(now: Date) {
        guard let start = rebaseStart else { return }
        let elapsed = now.timeIntervalSince(start)
        if elapsed >= rebaseTransitionDuration {
            baselineQuat = rebaseTargetQuat
            rebaseStart = nil
            settleReferencePitch = 0
            settleReferenceTwist = 0
            settledSince = now
            return
        }
        let t = elapsed / rebaseTransitionDuration
        let eased = 0.5 - 0.5 * cos(t * .pi)
        baselineQuat = Quaternion.slerp(from: rebaseFromQuat, to: rebaseTargetQuat, t: eased)
    }
}
