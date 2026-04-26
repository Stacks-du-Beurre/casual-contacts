import Foundation

/// A snapshot of every stage of the CoreMotion → DeviceAttitude pipeline,
/// captured per CMMotionManager callback. Carries raw sources, normalized
/// inputs, baseline-relative + smoothed + shaped intermediates, the final
/// throttled output (nil on dropped frames), and pipeline state markers
/// (settle timer, rebase progress).
///
/// Pure value type — no CoreMotion dependency — so it can live in CoreModels
/// alongside `DeviceAttitude` and travel through any module without
/// pulling iOS frameworks. Constructed by `CoreMotionService` and consumed
/// by `MotionDebugScene` in `FeatureSettings`.
public struct MotionDebugSample: Hashable, Sendable {

    public let timestamp: Date

    // Stage 0 — raw sources, untouched
    public let rawEulerPitch: Double      // radians
    public let rawEulerRoll: Double       // radians
    public let rawEulerYaw: Double        // radians
    public let rawQuaternion: SIMD4<Double>  // (x, y, z, w)
    public let gravity: SIMD3<Double>        // (x, y, z), unit vector

    // Stage 1 — normalized to ~±1 via ÷ (π/2)
    public let normalizedPitch: Double
    public let normalizedRoll: Double

    // Stage 2 — baseline + baseline-relative
    public let baseline: DeviceAttitude
    public let baselineRelative: DeviceAttitude

    // Stage 3 — smoothed (post low-pass)
    public let smoothed: DeviceAttitude

    // Stage 4 — shaped (post tanh)
    public let shaped: DeviceAttitude

    // Stage 5 — final throttled value (nil if this callback was dropped)
    public let throttledOutput: DeviceAttitude?

    // State markers
    public let secondsSinceSettleReset: TimeInterval
    public let isRebaseInProgress: Bool
    public let rebaseProgress: Double  // 0...1 when in progress, else 0

    public init(
        timestamp: Date,
        rawEulerPitch: Double,
        rawEulerRoll: Double,
        rawEulerYaw: Double,
        rawQuaternion: SIMD4<Double>,
        gravity: SIMD3<Double>,
        normalizedPitch: Double,
        normalizedRoll: Double,
        baseline: DeviceAttitude,
        baselineRelative: DeviceAttitude,
        smoothed: DeviceAttitude,
        shaped: DeviceAttitude,
        throttledOutput: DeviceAttitude?,
        secondsSinceSettleReset: TimeInterval,
        isRebaseInProgress: Bool,
        rebaseProgress: Double
    ) {
        self.timestamp = timestamp
        self.rawEulerPitch = rawEulerPitch
        self.rawEulerRoll = rawEulerRoll
        self.rawEulerYaw = rawEulerYaw
        self.rawQuaternion = rawQuaternion
        self.gravity = gravity
        self.normalizedPitch = normalizedPitch
        self.normalizedRoll = normalizedRoll
        self.baseline = baseline
        self.baselineRelative = baselineRelative
        self.smoothed = smoothed
        self.shaped = shaped
        self.throttledOutput = throttledOutput
        self.secondsSinceSettleReset = secondsSinceSettleReset
        self.isRebaseInProgress = isRebaseInProgress
        self.rebaseProgress = rebaseProgress
    }
}
