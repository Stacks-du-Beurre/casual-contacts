import Foundation
import CoreModels
#if canImport(CoreMotion) && !os(macOS)
import CoreMotion
import UIKit
#endif

// MARK: - Pure smoothing (unit-tested)

public final class AttitudeLowPass: @unchecked Sendable {

    private let alpha: Double
    private var state: DeviceAttitude?

    public init(alpha: Double) {
        self.alpha = alpha
    }

    /// Pure low-pass filter — does NOT clamp. Callers that need a bounded
    /// range must clamp their input / output themselves. This matters for
    /// consumers that feed baseline-relative attitudes whose natural range
    /// is wider than ±1 (a phone at baseline 0.5 tilted to raw -1 gives a
    /// relative pitch/roll of -1.5; clamping here would cause the animation
    /// to "stick" short of the phone's physical limit).
    @discardableResult
    public func smooth(_ raw: DeviceAttitude) -> DeviceAttitude {
        guard let previous = state else {
            state = raw
            return raw
        }
        let mixed = DeviceAttitude(
            pitch: previous.pitch + alpha * (raw.pitch - previous.pitch),
            roll: previous.roll + alpha * (raw.roll - previous.roll)
        )
        state = mixed
        return mixed
    }
}

// MARK: - Production service

#if canImport(CoreMotion) && !os(macOS)

public final class CoreMotionService: MotionService, @unchecked Sendable {

    private let manager = CMMotionManager()
    private let smoother = AttitudeLowPass(alpha: 0.1)
    private let throttle = AttitudeThrottle()
    private var attitudeContinuation: AsyncStream<DeviceAttitude>.Continuation?
    private var debugContinuation: AsyncStream<MotionDebugSample>.Continuation?

    private var baseline: DeviceAttitude?

    private var settleReference: DeviceAttitude = .zero
    private var settledSince: Date = Date()
    private var rebaseTransitionStart: Date?
    private var rebaseTransitionFrom: DeviceAttitude?
    private var rebaseTransitionTarget: DeviceAttitude?

    private let movementThreshold: Double = 0.05
    private let settleDuration: TimeInterval = 3.5
    private let rebaseTransitionDuration: TimeInterval = 1.0

    public let attitude: AsyncStream<DeviceAttitude>
    public let debugSamples: AsyncStream<MotionDebugSample>

    public init() {
        var attitudeContinuation: AsyncStream<DeviceAttitude>.Continuation!
        self.attitude = AsyncStream { attitudeContinuation = $0 }
        self.attitudeContinuation = attitudeContinuation

        var debugContinuation: AsyncStream<MotionDebugSample>.Continuation!
        self.debugSamples = AsyncStream { debugContinuation = $0 }
        self.debugContinuation = debugContinuation

        manager.deviceMotionUpdateInterval = 1.0 / 60.0
    }

    public func start() {
        if UIAccessibility.isReduceMotionEnabled {
            attitudeContinuation?.yield(.zero)
            return
        }
        guard manager.isDeviceMotionAvailable else { return }
        baseline = nil
        rebaseTransitionStart = nil
        rebaseTransitionFrom = nil
        rebaseTransitionTarget = nil
        settleReference = .zero
        settledSince = Date()

        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let now = Date()
            let raw = DeviceAttitude(
                pitch: motion.attitude.pitch / (.pi / 2),
                roll: motion.attitude.roll / (.pi / 2)
            )

            if self.baseline == nil {
                self.baseline = raw
                self.settledSince = now
                self.settleReference = .zero
            }

            let effectiveBaseline = self.stepRebaseTransition(now: now, raw: raw)
            let relative = DeviceAttitude(
                pitch: raw.pitch - effectiveBaseline.pitch,
                roll: raw.roll - effectiveBaseline.roll
            )
            let smoothed = self.smoother.smooth(relative)
            let shaped = DeviceAttitude(
                pitch: tanh(smoothed.pitch),
                roll: tanh(smoothed.roll)
            )

            if self.rebaseTransitionStart == nil {
                let delta = max(
                    abs(smoothed.pitch - self.settleReference.pitch),
                    abs(smoothed.roll - self.settleReference.roll)
                )
                if delta > self.movementThreshold {
                    self.settleReference = smoothed
                    self.settledSince = now
                } else if now.timeIntervalSince(self.settledSince) >= self.settleDuration {
                    self.rebaseTransitionStart = now
                    self.rebaseTransitionFrom = self.baseline ?? raw
                    self.rebaseTransitionTarget = raw
                }
            }

            let emitted = self.throttle.admit(shaped, now: now)
            if let emitted {
                self.attitudeContinuation?.yield(emitted)
            }

            #if DEBUG
            let rebaseProgress: Double
            if let start = self.rebaseTransitionStart {
                rebaseProgress = min(1, max(0, now.timeIntervalSince(start) / self.rebaseTransitionDuration))
            } else {
                rebaseProgress = 0
            }
            let sample = MotionDebugSample(
                timestamp: now,
                rawEulerPitch: motion.attitude.pitch,
                rawEulerRoll: motion.attitude.roll,
                rawEulerYaw: motion.attitude.yaw,
                rawQuaternion: SIMD4<Double>(
                    motion.attitude.quaternion.x,
                    motion.attitude.quaternion.y,
                    motion.attitude.quaternion.z,
                    motion.attitude.quaternion.w
                ),
                gravity: SIMD3<Double>(
                    motion.gravity.x,
                    motion.gravity.y,
                    motion.gravity.z
                ),
                normalizedPitch: raw.pitch,
                normalizedRoll: raw.roll,
                baseline: effectiveBaseline,
                baselineRelative: relative,
                smoothed: smoothed,
                shaped: shaped,
                throttledOutput: emitted,
                secondsSinceSettleReset: now.timeIntervalSince(self.settledSince),
                isRebaseInProgress: self.rebaseTransitionStart != nil,
                rebaseProgress: rebaseProgress
            )
            self.debugContinuation?.yield(sample)
            #endif
        }
    }

    public func stop() {
        manager.stopDeviceMotionUpdates()
    }

    private func stepRebaseTransition(now: Date, raw: DeviceAttitude) -> DeviceAttitude {
        guard
            let start = rebaseTransitionStart,
            let from = rebaseTransitionFrom,
            let target = rebaseTransitionTarget
        else {
            return baseline ?? .zero
        }
        let elapsed = now.timeIntervalSince(start)
        if elapsed >= rebaseTransitionDuration {
            baseline = target
            rebaseTransitionStart = nil
            rebaseTransitionFrom = nil
            rebaseTransitionTarget = nil
            settleReference = .zero
            settledSince = now
            return target
        }
        let t = elapsed / rebaseTransitionDuration
        let eased = 0.5 - 0.5 * cos(t * .pi)
        return DeviceAttitude(
            pitch: from.pitch + (target.pitch - from.pitch) * eased,
            roll: from.roll + (target.roll - from.roll) * eased
        )
    }
}

#endif

