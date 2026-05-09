import Foundation
import CoreModels

/// Rate-limits `DeviceAttitude` emission out of the motion pipeline. CoreMotion
/// delivers samples at 60 Hz, but every sample that reaches SwiftUI triggers a
/// re-evaluation across every visible `CardView`. For animated visuals, 30 Hz
/// is visually indistinguishable from 60 Hz once Core Animation interpolates,
/// and a further drop to ~12 Hz while the phone is stationary reclaims almost
/// all the per-tick cost when nothing is actually moving.
///
/// Pure class — no CoreMotion dependency — so the throttle logic is unit-tested
/// on the macOS host alongside `AttitudeLowPass`.
public final class AttitudeThrottle: @unchecked Sendable {

    /// Emission interval when recent samples show meaningful movement.
    public let baseInterval: TimeInterval
    /// Emission interval when the sampled motion is quieter than `movementThreshold`.
    public let idleInterval: TimeInterval
    /// Per-axis absolute delta from the previously emitted sample that counts as
    /// "moving". Below this on both axes, we fall back to `idleInterval`.
    public let movementThreshold: Double

    private var lastEmitted: Date?
    private var lastEmittedValue: DeviceAttitude?

    public init(
        baseInterval: TimeInterval = 1.0 / 60.0,
        idleInterval: TimeInterval = 1.0 / 12.0,
        movementThreshold: Double = 0.01
    ) {
        self.baseInterval = baseInterval
        self.idleInterval = idleInterval
        self.movementThreshold = movementThreshold
    }

    public func reset() {
        lastEmitted = nil
        lastEmittedValue = nil
    }

    /// Returns `sample` if the throttle decides to emit it, `nil` to drop.
    /// Always emits the first sample so consumers get an initial value.
    @discardableResult
    public func admit(_ sample: DeviceAttitude, now: Date) -> DeviceAttitude? {
        let interval = resolvedInterval(for: sample)
        if let last = lastEmitted, now.timeIntervalSince(last) + Self.boundaryEpsilon < interval {
            return nil
        }
        lastEmitted = now
        lastEmittedValue = sample
        return sample
    }

    /// Slack on the interval comparison so samples landing exactly on the
    /// interval boundary (e.g., 2/60 s after a prior emission with a 1/30 s
    /// interval) aren't dropped due to floating-point drift in the Date math.
    /// One microsecond is orders of magnitude below any real sample cadence.
    private static let boundaryEpsilon: TimeInterval = 1e-6

    /// Which interval applies to this sample given the previously emitted value.
    /// First sample (no prior emission) always uses `baseInterval`.
    private func resolvedInterval(for sample: DeviceAttitude) -> TimeInterval {
        guard let last = lastEmittedValue else { return baseInterval }
        let delta = max(abs(sample.pitch - last.pitch), abs(sample.roll - last.roll))
        return delta > movementThreshold ? baseInterval : idleInterval
    }
}
