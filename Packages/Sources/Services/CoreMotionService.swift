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
    private var continuation: AsyncStream<DeviceAttitude>.Continuation?

    // The first raw sample received after `start()` is captured as the
    // zero-point of the motion animation. All subsequent samples are yielded
    // relative to it, so effects rest at whatever pose the user is holding
    // the phone in when the app opens (rather than world-flat).
    private var baseline: DeviceAttitude?

    // Auto-rebase: if the user holds the phone in roughly the same pose for
    // `settleDuration`, the zero-point animates toward the current raw pose
    // over `rebaseTransitionDuration`. Accounts for hand / grip drift over
    // real-world usage without resetting while the user is actively enjoying
    // the parallax.
    private var settleReference: DeviceAttitude = .zero
    private var settledSince: Date = Date()
    private var rebaseTransitionStart: Date?
    private var rebaseTransitionFrom: DeviceAttitude?
    private var rebaseTransitionTarget: DeviceAttitude?

    /// Max pitch-or-roll delta (in the smoothed, baseline-relative space) that
    /// still counts as "settled". Above this, the settle timer resets.
    private let movementThreshold: Double = 0.05
    /// Time the attitude must remain within `movementThreshold` before we
    /// rebase the zero-point.
    private let settleDuration: TimeInterval = 3.5
    /// Duration over which the baseline slews from its current value to the
    /// new target — the animation visibly eases back to rest.
    private let rebaseTransitionDuration: TimeInterval = 1.0

    public let attitude: AsyncStream<DeviceAttitude>

    public init() {
        var continuation: AsyncStream<DeviceAttitude>.Continuation!
        self.attitude = AsyncStream { continuation = $0 }
        self.continuation = continuation
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
    }

    public func start() {
        // Reduce Motion bypass: if the user has Reduce Motion on at start time,
        // yield a single `.zero` sample and don't register the CoreMotion
        // callback at all. This avoids burning the 60 Hz delegate thread when
        // its output is going to be clamped to zero by ReducedMotionAdapter
        // anyway. RootScene calls `stop()` / `start()` on toggle to flip modes.
        if UIAccessibility.isReduceMotionEnabled {
            continuation?.yield(.zero)
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
            // Soft-saturation: `tanh` has unity slope at zero (preserving
            // sensitivity for small tilts) and smoothly asymptotes to ±1,
            // preventing consumers from over-driving when the phone is tilted
            // far from an off-center baseline.
            let shaped = DeviceAttitude(
                pitch: tanh(smoothed.pitch),
                roll: tanh(smoothed.roll)
            )

            // Settle detection is suspended during an in-progress rebase so a
            // fresh rebase can't fire on top of the ease-back.
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

            // Rate-limit emission: 30 Hz while moving, ~12 Hz when stationary.
            // CoreMotion keeps feeding us at 60 Hz so the smoother + rebase
            // logic above stay high-resolution; only the downstream yield is
            // throttled.
            if let emitted = self.throttle.admit(shaped, now: now) {
                self.continuation?.yield(emitted)
            }
        }
    }

    /// Halts the CoreMotion callback without finishing the stream. Callers can
    /// `start()` again later (e.g., when Reduce Motion is toggled off) and the
    /// same `attitude` consumer loop will continue receiving samples.
    public func stop() {
        manager.stopDeviceMotionUpdates()
    }

    /// Advance any in-flight rebase transition and return the baseline the
    /// caller should use for this frame. When the transition completes, the
    /// transition state is cleared and settle-detection is reset so we don't
    /// immediately retrigger.
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
        let eased = 0.5 - 0.5 * cos(t * .pi)  // cosine ease-in-out
        return DeviceAttitude(
            pitch: from.pitch + (target.pitch - from.pitch) * eased,
            roll: from.roll + (target.roll - from.roll) * eased
        )
    }
}

#endif
