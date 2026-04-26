# Motion Debug Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `#if DEBUG` motion-debug screen that exposes every stage of the CoreMotion → `DeviceAttitude` pipeline live, so we can directly observe gimbal-lock behavior near vertical (and any other discontinuities) and design a remediation strategy from real signals instead of intuition.

**Architecture:** Add a side-channel `debugSamples` `AsyncStream<MotionDebugSample>` to `MotionService`. `CoreMotionService` populates it from the same CMMotionManager callback that already drives the production stream — no parallel pipeline, no drift. A new `MotionDebugScene` in `FeatureSettings` subscribes only while visible, feeds a non-Observable ring-buffer view-model, and renders 9 signals as numerics + 10s rolling sparklines plus a 2D pitch×roll dot, driven by `TimelineView(.animation)` so SwiftUI re-evaluates at display refresh rather than 60 Hz sample arrival.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, `SwiftUI.Canvas`, `TimelineView`, `AsyncStream`, Swift Testing (`@Suite` / `@Test`), `CMMotionManager` (for the existing pipeline; not new in this plan).

**Spec:** `docs/superpowers/specs/2026-04-26-motion-debug-screen-design.md`

---

## File Structure

### Created

- `Packages/Sources/CoreModels/Types/MotionDebugSample.swift` — pure value type carrying every pipeline stage + state markers. Hashable, Sendable, no framework deps.
- `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugViewModel.swift` — non-Observable ring-buffer + Hz estimator. Pure logic, host-testable.
- `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugScene.swift` — top-level screen.
- `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugPinnedRegion.swift` — 2D dot + state chips (settle countdown, rebase, Hz).
- `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugSignalRow.swift` — one row: label, numeric column, sparkline canvas.
- `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugSparkline.swift` — multi-channel sparkline `Canvas` view.
- `Packages/Tests/CoreModelsTests/MotionDebugSampleTests.swift` — value-type equality + field round-trip.
- `Packages/Tests/FeatureSettingsTests/MotionDebugViewModelTests.swift` — ring-buffer wrap, Hz window math, snapshot semantics.

### Modified

- `Packages/Sources/CoreModels/Protocols/MotionService.swift` — add `var debugSamples: AsyncStream<MotionDebugSample> { get }`.
- `Packages/Sources/Services/CoreMotionService.swift` — populate `debugSamples` from the existing CoreMotion callback. Yield gated by `#if DEBUG` so release builds incur zero per-frame cost beyond struct value creation in the inactive branch.
- `Packages/Sources/ServicesTestSupport/StaticMotionService.swift` — add never-yielding `debugSamples` stream.
- `Packages/Sources/AppFeature/ScreenshotServices.swift` — add never-yielding `debugSamples` on `ScreenshotMotionService`.
- `Packages/Sources/FeatureSettings/SettingsSheet.swift` — add `.motionDebug` route (`#if DEBUG`), settings row, optional `motionService` injection.
- `Packages/Sources/AppFeature/RootScene.swift` — pass `environment.motionService` into `SettingsSheet`.
- `Packages/Tests/ServicesTestSupportTests/StaticMotionServiceTests.swift` — assert `debugSamples` exists and is never-yielding.

### File Layout Rationale

`MotionDebug/` subfolder under `FeatureSettings` keeps the disposable surface area neatly co-located so it's a one-line `rm -rf` when the follow-up pipeline-fix spec lands. The view-model is split out so we can host-test it without SwiftUI runtime.

---

## Task 1: `MotionDebugSample` value type

**Files:**
- Create: `Packages/Sources/CoreModels/Types/MotionDebugSample.swift`
- Test: `Packages/Tests/CoreModelsTests/MotionDebugSampleTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/Tests/CoreModelsTests/MotionDebugSampleTests.swift`:

```swift
import Testing
import Foundation
@testable import CoreModels

@Suite struct MotionDebugSampleTests {

    private func makeSample(
        rawPitch: Double = 0.1,
        rawRoll: Double = 0.2,
        rawYaw: Double = 0.3,
        throttled: DeviceAttitude? = DeviceAttitude(pitch: 0.4, roll: 0.5)
    ) -> MotionDebugSample {
        MotionDebugSample(
            timestamp: Date(timeIntervalSince1970: 100),
            rawEulerPitch: rawPitch,
            rawEulerRoll: rawRoll,
            rawEulerYaw: rawYaw,
            rawQuaternion: SIMD4<Double>(0, 0, 0, 1),
            gravity: SIMD3<Double>(0, 0, -1),
            normalizedPitch: 0.06,
            normalizedRoll: 0.13,
            baseline: .zero,
            baselineRelative: DeviceAttitude(pitch: 0.06, roll: 0.13),
            smoothed: DeviceAttitude(pitch: 0.05, roll: 0.10),
            shaped: DeviceAttitude(pitch: 0.05, roll: 0.10),
            throttledOutput: throttled,
            secondsSinceSettleReset: 1.5,
            isRebaseInProgress: false,
            rebaseProgress: 0.0
        )
    }

    @Test func equalSamplesAreEqual() {
        let a = makeSample()
        let b = makeSample()
        #expect(a == b)
    }

    @Test func differingFieldsAreNotEqual() {
        let a = makeSample(rawPitch: 0.1)
        let b = makeSample(rawPitch: 0.2)
        #expect(a != b)
    }

    @Test func droppedFrameHasNilThrottledOutput() {
        let dropped = makeSample(throttled: nil)
        #expect(dropped.throttledOutput == nil)
    }

    @Test func sampleIsSendableAndHashable() {
        let a = makeSample()
        let set: Set<MotionDebugSample> = [a]
        #expect(set.contains(a))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/adam/Projects/cc/.worktrees/motion-debug-screen/Packages
swift test --filter MotionDebugSampleTests 2>&1 | tail -20
```

Expected: compile failure — `MotionDebugSample` is undefined.

- [ ] **Step 3: Implement the type**

Create `Packages/Sources/CoreModels/Types/MotionDebugSample.swift`:

```swift
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
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter MotionDebugSampleTests 2>&1 | tail -10
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/CoreModels/Types/MotionDebugSample.swift Packages/Tests/CoreModelsTests/MotionDebugSampleTests.swift
git commit -m "$(cat <<'EOF'
feat(coremodels): MotionDebugSample value type

Carries every stage of the motion pipeline (raw Euler, quaternion, gravity,
normalized, baseline-relative, smoothed, shaped, throttled, plus state markers)
in one Hashable/Sendable struct. Built per CoreMotion callback by the next
task; consumed by the debug screen later.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Extend `MotionService` protocol with `debugSamples`

**Files:**
- Modify: `Packages/Sources/CoreModels/Protocols/MotionService.swift`

- [ ] **Step 1: No new test — protocol changes are validated by conformance compile of `StaticMotionService` / `ScreenshotMotionService` / `CoreMotionService` in the next tasks.**

- [ ] **Step 2: Modify the protocol**

Replace the contents of `Packages/Sources/CoreModels/Protocols/MotionService.swift` with:

```swift
import Foundation

public protocol MotionService: AnyObject, Sendable {
    /// The production attitude stream. Throttled, smoothed, shaped — the value
    /// every visual consumer (CardView, etc.) reads.
    var attitude: AsyncStream<DeviceAttitude> { get }

    /// Side-channel debug stream. Yields one `MotionDebugSample` per inbound
    /// motion-sensor callback (i.e., regardless of the production-stream
    /// throttle). Carries every pipeline stage so a debug screen can show the
    /// signal at every step. Never-yielding on fakes / release builds where
    /// the sensor isn't wired. Always present on the protocol so consumers
    /// don't need conditional dispatch.
    var debugSamples: AsyncStream<MotionDebugSample> { get }

    func start()
    func stop()
}
```

- [ ] **Step 3: Compile**

```bash
swift build 2>&1 | tail -20
```

Expected: build fails with conformance errors in `StaticMotionService`, `ScreenshotMotionService`, `CoreMotionService` because none of them implements `debugSamples` yet. **This is expected** — the next tasks fix each conformance.

- [ ] **Step 4: Commit**

```bash
git add Packages/Sources/CoreModels/Protocols/MotionService.swift
git commit -m "$(cat <<'EOF'
feat(coremodels): MotionService gains debugSamples side-channel

A second AsyncStream that yields per-callback MotionDebugSample, regardless
of the production-stream throttle. Always present on the protocol; fakes
and release-build conformances will leave it never-yielding. Build is broken
between this commit and the conformance-fixing commits that follow — fix lands
in the next two tasks.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Conform `StaticMotionService` to `debugSamples`

**Files:**
- Modify: `Packages/Sources/ServicesTestSupport/StaticMotionService.swift`
- Modify: `Packages/Tests/ServicesTestSupportTests/StaticMotionServiceTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `Packages/Tests/ServicesTestSupportTests/StaticMotionServiceTests.swift` (inside the existing `@Suite struct StaticMotionServiceTests {`):

```swift
    @Test func debugSamplesStreamExistsAndIsNeverYielding() async {
        let service = StaticMotionService()
        service.start()

        // Race a 50ms timeout against the debug stream — we expect the stream
        // to never yield. If the timeout wins, the test passes.
        let didYieldDebugSample = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in service.debugSamples {
                    return true
                }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(50))
                return false
            }
            // Take whichever finishes first.
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }

        #expect(didYieldDebugSample == false)
    }
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter StaticMotionServiceTests 2>&1 | tail -20
```

Expected: compile failure — `StaticMotionService` does not provide `debugSamples`.

- [ ] **Step 3: Implement conformance**

Replace the contents of `Packages/Sources/ServicesTestSupport/StaticMotionService.swift` with:

```swift
import Foundation
import CoreModels

public final class StaticMotionService: MotionService, @unchecked Sendable {

    private let fixedAttitude: DeviceAttitude
    private var attitudeContinuation: AsyncStream<DeviceAttitude>.Continuation?
    public let attitude: AsyncStream<DeviceAttitude>

    /// Never-yielding by design — fakes don't run a sensor callback and
    /// nothing in test code needs the debug pipeline. Wiring it as a real
    /// AsyncStream (vs. nil) keeps the protocol simple: consumers always
    /// `for await` the same way.
    public let debugSamples: AsyncStream<MotionDebugSample>
    private var debugContinuation: AsyncStream<MotionDebugSample>.Continuation?

    public init(attitude: DeviceAttitude = .zero) {
        self.fixedAttitude = attitude

        var attitudeContinuation: AsyncStream<DeviceAttitude>.Continuation!
        self.attitude = AsyncStream { attitudeContinuation = $0 }
        self.attitudeContinuation = attitudeContinuation

        var debugContinuation: AsyncStream<MotionDebugSample>.Continuation!
        self.debugSamples = AsyncStream { debugContinuation = $0 }
        self.debugContinuation = debugContinuation
    }

    public func start() {
        attitudeContinuation?.yield(fixedAttitude)
    }

    public func stop() {
        attitudeContinuation?.finish()
        attitudeContinuation = nil
        debugContinuation?.finish()
        debugContinuation = nil
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter StaticMotionServiceTests 2>&1 | tail -10
```

Expected: 3 tests pass (`publishesSingleStaticAttitude`, `stopEndsTheStream`, `debugSamplesStreamExistsAndIsNeverYielding`).

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/ServicesTestSupport/StaticMotionService.swift Packages/Tests/ServicesTestSupportTests/StaticMotionServiceTests.swift
git commit -m "$(cat <<'EOF'
feat(servicestestsupport): StaticMotionService conforms to debugSamples

Never-yielding AsyncStream wired so test code can hold a uniform protocol
shape. stop() also finishes the debug continuation to avoid leaking the
stream when tests cycle services.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Conform `ScreenshotMotionService` to `debugSamples`

**Files:**
- Modify: `Packages/Sources/AppFeature/ScreenshotServices.swift`

- [ ] **Step 1: Modify the conformance**

Replace the `ScreenshotMotionService` class in `Packages/Sources/AppFeature/ScreenshotServices.swift` with:

```swift
final class ScreenshotMotionService: MotionService, @unchecked Sendable {

    private var attitudeContinuation: AsyncStream<DeviceAttitude>.Continuation?
    let attitude: AsyncStream<DeviceAttitude>

    /// Screenshot mode never wants motion; the debug stream is also a no-op
    /// to keep the conformance trivial.
    let debugSamples: AsyncStream<MotionDebugSample>
    private var debugContinuation: AsyncStream<MotionDebugSample>.Continuation?

    init() {
        var attitudeContinuation: AsyncStream<DeviceAttitude>.Continuation!
        self.attitude = AsyncStream { attitudeContinuation = $0 }
        self.attitudeContinuation = attitudeContinuation

        var debugContinuation: AsyncStream<MotionDebugSample>.Continuation!
        self.debugSamples = AsyncStream { debugContinuation = $0 }
        self.debugContinuation = debugContinuation
    }

    func start() {
        attitudeContinuation?.yield(.zero)
    }

    func stop() {
        attitudeContinuation?.finish()
        attitudeContinuation = nil
        debugContinuation?.finish()
        debugContinuation = nil
    }
}
```

(Leave `ScreenshotLocationService` below it untouched.)

- [ ] **Step 2: Build to verify the conformance compiles**

```bash
swift build 2>&1 | tail -10
```

Expected: build still fails — `CoreMotionService` is the last remaining non-conforming type. Move on; the next task fixes it.

- [ ] **Step 3: Commit**

```bash
git add Packages/Sources/AppFeature/ScreenshotServices.swift
git commit -m "$(cat <<'EOF'
feat(appfeature): ScreenshotMotionService conforms to debugSamples

Never-yielding stream — screenshot mode never animates so there's nothing
useful to surface in the debug pipeline either.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `CoreMotionService` populates `debugSamples`

**Files:**
- Modify: `Packages/Sources/Services/CoreMotionService.swift`

- [ ] **Step 1: Modify the file**

Replace the entire contents of `Packages/Sources/Services/CoreMotionService.swift` with:

```swift
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

// MARK: - Non-iOS shim

#if !canImport(CoreMotion) || os(macOS)

/// Host-side stub — CoreMotion is iOS-only. Never yields. Lets the package
/// compile on macOS for unit-testing the surrounding code.
public final class CoreMotionService: MotionService, @unchecked Sendable {

    public let attitude: AsyncStream<DeviceAttitude>
    public let debugSamples: AsyncStream<MotionDebugSample>

    public init() {
        self.attitude = AsyncStream { _ in }
        self.debugSamples = AsyncStream { _ in }
    }

    public func start() {}
    public func stop() {}
}

#endif
```

> **Note on the macOS stub:** the file before this task didn't include a non-iOS branch because nothing referenced `CoreMotionService` from macOS test targets. With `debugSamples` now part of the protocol and `MotionDebugSample` in `CoreModels`, we add a thin stub so `swift build` on macOS still succeeds. (If `swift build` already succeeded with no stub before this change, the existing call sites must all be `#if`-gated; verify by removing the `#if !canImport(...)` block and re-running `swift build` — if it builds clean on macOS, drop the stub. Don't ship dead code.)

- [ ] **Step 2: Build for both targets**

```bash
swift build 2>&1 | tail -20
```

Expected: build succeeds on macOS host.

```bash
xcodebuild build \
    -scheme CasualContacts \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    2>&1 | tail -20
```

Expected: build succeeds on iOS simulator.

- [ ] **Step 3: Run the existing motion tests to make sure no regressions**

```bash
swift test --filter CoreMotionSmoothingTests 2>&1 | tail -10
swift test --filter AttitudeThrottleTests 2>&1 | tail -10
```

Expected: both pre-existing test suites still pass unchanged.

- [ ] **Step 4: Commit**

```bash
git add Packages/Sources/Services/CoreMotionService.swift
git commit -m "$(cat <<'EOF'
feat(services): CoreMotionService populates debugSamples per callback

Yields one MotionDebugSample per CMMotionManager callback, gated by #if DEBUG
so release builds incur no per-frame cost. Sample is constructed from the same
intermediate locals (raw, normalized, baseline-relative, smoothed, shaped,
throttle output) the production stream already computes — no parallel pipeline.
Non-iOS stub added so the package still builds on macOS.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `MotionDebugViewModel` — ring buffer + Hz estimator

**Files:**
- Create: `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugViewModel.swift`
- Test: `Packages/Tests/FeatureSettingsTests/MotionDebugViewModelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/Tests/FeatureSettingsTests/MotionDebugViewModelTests.swift`:

```swift
import Testing
import Foundation
import CoreModels
@testable import FeatureSettings

@Suite struct MotionDebugViewModelTests {

    private func sample(
        at t: TimeInterval,
        emitted: Bool = true,
        rawPitch: Double = 0
    ) -> MotionDebugSample {
        MotionDebugSample(
            timestamp: Date(timeIntervalSince1970: t),
            rawEulerPitch: rawPitch,
            rawEulerRoll: 0,
            rawEulerYaw: 0,
            rawQuaternion: SIMD4<Double>(0, 0, 0, 1),
            gravity: SIMD3<Double>(0, 0, -1),
            normalizedPitch: 0,
            normalizedRoll: 0,
            baseline: .zero,
            baselineRelative: .zero,
            smoothed: .zero,
            shaped: .zero,
            throttledOutput: emitted ? .zero : nil,
            secondsSinceSettleReset: 0,
            isRebaseInProgress: false,
            rebaseProgress: 0
        )
    }

    @Test func snapshotIsEmptyBeforeAnySample() {
        let viewModel = MotionDebugViewModel(capacity: 4)
        let snapshot = viewModel.snapshot()
        #expect(snapshot.samples.isEmpty)
        #expect(snapshot.latest == nil)
    }

    @Test func appendStoresLatest() {
        let viewModel = MotionDebugViewModel(capacity: 4)
        let sample = sample(at: 1, rawPitch: 0.42)
        viewModel.append(sample)
        let snapshot = viewModel.snapshot()
        #expect(snapshot.latest == sample)
        #expect(snapshot.samples.count == 1)
    }

    @Test func ringBufferDropsOldestWhenFull() {
        let viewModel = MotionDebugViewModel(capacity: 3)
        for i in 0..<5 {
            viewModel.append(sample(at: TimeInterval(i)))
        }
        let snapshot = viewModel.snapshot()
        #expect(snapshot.samples.count == 3)
        // Should be the last three (timestamps 2, 3, 4)
        #expect(snapshot.samples.first?.timestamp == Date(timeIntervalSince1970: 2))
        #expect(snapshot.samples.last?.timestamp == Date(timeIntervalSince1970: 4))
    }

    @Test func emissionRateCountsThrottledOutputsInLastSecond() {
        let viewModel = MotionDebugViewModel(capacity: 600)

        // 30 emitted samples and 30 dropped samples spaced over the last 1 s.
        // Hz should report 30 (we count emitted only).
        let now = Date(timeIntervalSince1970: 100)
        for i in 0..<60 {
            let t = now.addingTimeInterval(-1.0 + Double(i) * (1.0 / 60.0))
            let emitted = i % 2 == 0
            viewModel.append(sample(at: t.timeIntervalSince1970, emitted: emitted))
        }

        // One sample exactly at `now` to anchor the window.
        viewModel.append(sample(at: now.timeIntervalSince1970, emitted: true))

        #expect(viewModel.emissionRate(referenceTime: now) >= 28)
        #expect(viewModel.emissionRate(referenceTime: now) <= 32)
    }

    @Test func emissionRateIgnoresSamplesOlderThanOneSecond() {
        let viewModel = MotionDebugViewModel(capacity: 600)
        let now = Date(timeIntervalSince1970: 100)

        // Old sample 5 seconds ago — must be ignored.
        viewModel.append(sample(at: now.addingTimeInterval(-5).timeIntervalSince1970, emitted: true))
        // Fresh sample at now.
        viewModel.append(sample(at: now.timeIntervalSince1970, emitted: true))

        #expect(viewModel.emissionRate(referenceTime: now) == 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
swift test --filter MotionDebugViewModelTests 2>&1 | tail -15
```

Expected: compile failure — `MotionDebugViewModel` undefined.

- [ ] **Step 3: Implement the view-model**

Create `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugViewModel.swift`:

```swift
import Foundation
import CoreModels

/// Non-Observable holder for the debug screen's rolling sample buffer. Built
/// to be cheap on the hot path: `append(_:)` is O(1) and never triggers a
/// SwiftUI re-evaluation. The view drives redraws via `TimelineView(.animation)`
/// and pulls a `Snapshot` per refresh tick — not per sample arrival.
///
/// Pure logic, host-testable. No SwiftUI imports.
public final class MotionDebugViewModel: @unchecked Sendable {

    public struct Snapshot: Sendable {
        public let samples: [MotionDebugSample]   // oldest → newest
        public let latest: MotionDebugSample?
    }

    private let capacity: Int
    private var buffer: [MotionDebugSample] = []
    private let lock = NSLock()

    public init(capacity: Int = 600) {
        self.capacity = capacity
        buffer.reserveCapacity(capacity)
    }

    /// Append a new sample. If the buffer has reached `capacity`, the oldest
    /// sample is dropped. Thread-safe via `NSLock` because `append` is called
    /// from the AsyncStream consumer task while `snapshot` runs on the main
    /// thread for the Canvas redraw.
    public func append(_ sample: MotionDebugSample) {
        lock.lock()
        defer { lock.unlock() }
        if buffer.count == capacity {
            buffer.removeFirst()
        }
        buffer.append(sample)
    }

    /// Read-only copy for drawing. Cheap because the buffer is bounded.
    public func snapshot() -> Snapshot {
        lock.lock()
        let copy = buffer
        lock.unlock()
        return Snapshot(samples: copy, latest: copy.last)
    }

    /// Number of samples in the last 1 s where `throttledOutput != nil`.
    /// Caller passes the reference time so this is testable without
    /// `Date()`. The screen passes `Date()`.
    public func emissionRate(referenceTime: Date) -> Int {
        lock.lock()
        let copy = buffer
        lock.unlock()
        let cutoff = referenceTime.addingTimeInterval(-1.0)
        return copy.reduce(0) { count, sample in
            guard sample.throttledOutput != nil else { return count }
            return sample.timestamp >= cutoff ? count + 1 : count
        }
    }
}
```

Note: `MotionDebugViewModel` lives in `FeatureSettings` and is `public` only because `FeatureSettingsTests` needs to reach it via `@testable import FeatureSettings` — `@testable` actually grants access to internal members, but keeping `public` makes the contract explicit since it's also consumed by `MotionDebugScene` in the same module. (Internal would also work; pick `public` for the screen surface, `internal` would be fine for the view-model. Keep `public` for symmetry with the rest of `FeatureSettings`'s exported view models if any; otherwise mark `internal` and remove `public` from declarations.)

> **Decision:** mark all members `public` for now. We can tighten later if the type is never reached cross-module.

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter MotionDebugViewModelTests 2>&1 | tail -15
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/FeatureSettings/MotionDebug/MotionDebugViewModel.swift Packages/Tests/FeatureSettingsTests/MotionDebugViewModelTests.swift
git commit -m "$(cat <<'EOF'
feat(featuresettings): MotionDebugViewModel ring buffer + Hz estimator

Bounded buffer of MotionDebugSample, snapshot() copy for drawing, emissionRate(referenceTime:)
counts throttled emissions in the last 1 s. NSLock-guarded because the writer
task and the SwiftUI Canvas redraw run on different threads. Pure-logic class —
no SwiftUI dependency, fully tested host-side.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `MotionDebugSparkline` — multi-channel canvas

**Files:**
- Create: `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugSparkline.swift`

- [ ] **Step 1: Implement the sparkline view**

No unit test — pure SwiftUI rendering, validated visually in Task 11.

Create `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugSparkline.swift`:

```swift
import SwiftUI
import CoreModels

/// Multi-channel line chart over a time window. Each channel is one (label,
/// color, value-extractor) tuple; the canvas draws each as a `Path` over the
/// last `windowDuration` seconds, with a faint zero-line and a y-range
/// caller-supplied so semantically related rows can share scales (e.g. all
/// quaternion components at ±1).
///
/// Drawing is driven by the parent's TimelineView, so the canvas only
/// re-evaluates at display refresh.
struct MotionDebugSparkline: View {

    struct Channel {
        let label: String
        let color: Color
        let value: (MotionDebugSample) -> Double
    }

    let samples: [MotionDebugSample]
    let referenceTime: Date
    let windowDuration: TimeInterval
    let yRange: ClosedRange<Double>
    let channels: [Channel]

    var body: some View {
        Canvas { context, size in
            // Background + zero line
            let zeroNormalized = (0 - yRange.lowerBound) / (yRange.upperBound - yRange.lowerBound)
            let zeroY = size.height * (1 - zeroNormalized)
            let zeroLine = Path { p in
                p.move(to: CGPoint(x: 0, y: zeroY))
                p.addLine(to: CGPoint(x: size.width, y: zeroY))
            }
            context.stroke(zeroLine, with: .color(.gray.opacity(0.25)), lineWidth: 0.5)

            guard !samples.isEmpty else { return }

            for channel in channels {
                let path = Path { p in
                    var first = true
                    for sample in samples {
                        let dt = referenceTime.timeIntervalSince(sample.timestamp)
                        guard dt <= windowDuration, dt >= 0 else { continue }
                        let x = size.width * CGFloat(1 - dt / windowDuration)
                        let raw = channel.value(sample)
                        let normalized = (raw - yRange.lowerBound) / (yRange.upperBound - yRange.lowerBound)
                        let clamped = min(max(normalized, 0), 1)
                        let y = size.height * CGFloat(1 - clamped)
                        let point = CGPoint(x: x, y: y)
                        if first {
                            p.move(to: point)
                            first = false
                        } else {
                            p.addLine(to: point)
                        }
                    }
                }
                context.stroke(path, with: .color(channel.color), lineWidth: 1.0)
            }
        }
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

```bash
swift build 2>&1 | tail -10
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Packages/Sources/FeatureSettings/MotionDebug/MotionDebugSparkline.swift
git commit -m "$(cat <<'EOF'
feat(featuresettings): MotionDebugSparkline multi-channel canvas

SwiftUI.Canvas line chart over a time window. Each channel = (label, color,
extractor); shared y-range per row so quaternion components or pitch/roll
pairs scale together. Driven by parent TimelineView — redraws at display
refresh, not per sample.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: `MotionDebugSignalRow`

**Files:**
- Create: `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugSignalRow.swift`

- [ ] **Step 1: Implement the row**

Create `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugSignalRow.swift`:

```swift
import SwiftUI
import CoreModels

/// One row in the debug screen's scrolling list. Left side: row title +
/// fixed-width numeric column showing each channel's current value. Right
/// side: the rolling-strip sparkline.
struct MotionDebugSignalRow: View {

    let title: String
    let latest: MotionDebugSample?
    let samples: [MotionDebugSample]
    let referenceTime: Date
    let windowDuration: TimeInterval
    let yRange: ClosedRange<Double>
    let channels: [MotionDebugSparkline.Channel]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(channels.enumerated()), id: \.offset) { _, channel in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(channel.color)
                            .frame(width: 6, height: 6)
                        Text(channel.label)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Text(numericString(for: channel))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
            }
            .frame(width: 130, alignment: .leading)

            MotionDebugSparkline(
                samples: samples,
                referenceTime: referenceTime,
                windowDuration: windowDuration,
                yRange: yRange,
                channels: channels
            )
            .frame(maxWidth: .infinity)
            .frame(height: 60)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }

    private func numericString(for channel: MotionDebugSparkline.Channel) -> String {
        guard let latest else { return "—" }
        let value = channel.value(latest)
        return String(format: "%+0.3f", value)
    }
}
```

- [ ] **Step 2: Build**

```bash
swift build 2>&1 | tail -10
```

Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Packages/Sources/FeatureSettings/MotionDebug/MotionDebugSignalRow.swift
git commit -m "$(cat <<'EOF'
feat(featuresettings): MotionDebugSignalRow

One row of the debug list: title, fixed-width numeric column with channel
swatches, sparkline canvas to the right.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: `MotionDebugPinnedRegion` — 2D dot + state chips

**Files:**
- Create: `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugPinnedRegion.swift`

- [ ] **Step 1: Implement**

Create `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugPinnedRegion.swift`:

```swift
import SwiftUI
import CoreModels

/// Pinned top region of the debug screen.
///
/// Left half: a unit-square 2D plot of (shaped.pitch, shaped.roll). Origin
/// at center, ±1 at edges. A faint trail of the last `trailDuration` seconds
/// gives motion direction at a glance.
///
/// Right half: three state chips — settle countdown, rebase progress, and
/// the throttled emission rate (Hz) over the last 1 s.
struct MotionDebugPinnedRegion: View {

    let snapshot: MotionDebugViewModel.Snapshot
    let emissionRate: Int
    let referenceTime: Date

    private let trailDuration: TimeInterval = 1.0

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            dot
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 180)

            VStack(alignment: .leading, spacing: 12) {
                settleChip
                rebaseChip
                hzChip
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    private var dot: some View {
        Canvas { context, size in
            // Frame
            let frame = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4)
            context.stroke(frame, with: .color(.gray.opacity(0.4)), lineWidth: 1)

            // Crosshairs
            let cross = Path { p in
                p.move(to: CGPoint(x: size.width / 2, y: 0))
                p.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                p.move(to: CGPoint(x: 0, y: size.height / 2))
                p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            }
            context.stroke(cross, with: .color(.gray.opacity(0.25)), lineWidth: 0.5)

            // Trail (last `trailDuration`)
            let trail = Path { p in
                var first = true
                for sample in snapshot.samples {
                    let dt = referenceTime.timeIntervalSince(sample.timestamp)
                    guard dt <= trailDuration, dt >= 0 else { continue }
                    let x = size.width * CGFloat((sample.shaped.pitch + 1) / 2)
                    let y = size.height * CGFloat((sample.shaped.roll + 1) / 2)
                    let point = CGPoint(x: x, y: y)
                    if first { p.move(to: point); first = false }
                    else { p.addLine(to: point) }
                }
            }
            context.stroke(trail, with: .color(.accentColor.opacity(0.5)), lineWidth: 1)

            // Current dot
            if let latest = snapshot.latest {
                let cx = size.width * CGFloat((latest.shaped.pitch + 1) / 2)
                let cy = size.height * CGFloat((latest.shaped.roll + 1) / 2)
                let dot = Path(ellipseIn: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8))
                context.fill(dot, with: .color(.accentColor))
            }
        }
    }

    private var settleChip: some View {
        let total: TimeInterval = 3.5
        let remaining = max(0, total - (snapshot.latest?.secondsSinceSettleReset ?? 0))
        let armed = remaining > 0 && remaining < total
        return chip(
            label: "settle",
            value: String(format: "%.1fs", remaining),
            tint: armed ? .orange : .secondary
        )
    }

    private var rebaseChip: some View {
        let inProgress = snapshot.latest?.isRebaseInProgress == true
        let progress = snapshot.latest?.rebaseProgress ?? 0
        return HStack(spacing: 8) {
            chip(label: "rebase", value: inProgress ? "in progress" : "idle", tint: inProgress ? .orange : .secondary)
            if inProgress {
                ProgressView(value: progress)
                    .frame(width: 80)
            }
        }
    }

    private var hzChip: some View {
        chip(label: "Hz", value: "\(emissionRate)", tint: .primary)
    }

    private func chip(label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(tint)
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
swift build 2>&1 | tail -10
```

Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Packages/Sources/FeatureSettings/MotionDebug/MotionDebugPinnedRegion.swift
git commit -m "$(cat <<'EOF'
feat(featuresettings): MotionDebugPinnedRegion 2D dot + state chips

Unit-square Canvas with crosshairs, faint 1s trail, current-shape dot,
plus three state chips (settle countdown, rebase progress, Hz).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: `MotionDebugScene`

**Files:**
- Create: `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugScene.swift`

- [ ] **Step 1: Implement**

Create `Packages/Sources/FeatureSettings/MotionDebug/MotionDebugScene.swift`:

```swift
import SwiftUI
import CoreModels

/// Top-level debug screen. Subscribes to `service.debugSamples` only while
/// the view is on screen (SwiftUI cancels the `.task` on disappear). Drives
/// repaints from `TimelineView(.animation)` so the Canvas redraws at display
/// refresh, not per sample arrival.
@MainActor
public struct MotionDebugScene: View {

    public let service: any MotionService

    @State private var viewModel = MotionDebugViewModel()

    public init(service: any MotionService) {
        self.service = service
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let snapshot = viewModel.snapshot()
            let now = timeline.date
            let rate = viewModel.emissionRate(referenceTime: now)

            ScrollView {
                VStack(spacing: 0) {
                    MotionDebugPinnedRegion(
                        snapshot: snapshot,
                        emissionRate: rate,
                        referenceTime: now
                    )
                    Divider()
                    LazyVStack(spacing: 0) {
                        signalRows(snapshot: snapshot, now: now)
                    }
                }
            }
        }
        .navigationTitle("Motion Debug")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            for await sample in service.debugSamples {
                viewModel.append(sample)
            }
        }
    }

    @ViewBuilder
    private func signalRows(
        snapshot: MotionDebugViewModel.Snapshot,
        now: Date
    ) -> some View {
        let window: TimeInterval = 10

        Group {
            // 1. Raw Euler
            row(
                "Raw Euler (rad)",
                snapshot: snapshot,
                now: now,
                window: window,
                yRange: -Double.pi ... Double.pi,
                channels: [
                    .init(label: "p", color: .red,   value: { $0.rawEulerPitch }),
                    .init(label: "r", color: .green, value: { $0.rawEulerRoll }),
                    .init(label: "y", color: .blue,  value: { $0.rawEulerYaw })
                ]
            )

            // 2. Quaternion
            row(
                "Quaternion",
                snapshot: snapshot, now: now, window: window,
                yRange: -1...1,
                channels: [
                    .init(label: "x", color: .red,    value: { $0.rawQuaternion.x }),
                    .init(label: "y", color: .green,  value: { $0.rawQuaternion.y }),
                    .init(label: "z", color: .blue,   value: { $0.rawQuaternion.z }),
                    .init(label: "w", color: .orange, value: { $0.rawQuaternion.w })
                ]
            )

            // 3. Gravity
            row(
                "Gravity",
                snapshot: snapshot, now: now, window: window,
                yRange: -1...1,
                channels: [
                    .init(label: "x", color: .red,   value: { $0.gravity.x }),
                    .init(label: "y", color: .green, value: { $0.gravity.y }),
                    .init(label: "z", color: .blue,  value: { $0.gravity.z })
                ]
            )

            // 4. Normalized
            row(
                "Normalized",
                snapshot: snapshot, now: now, window: window,
                yRange: -2...2,
                channels: [
                    .init(label: "p", color: .red,   value: { $0.normalizedPitch }),
                    .init(label: "r", color: .green, value: { $0.normalizedRoll })
                ]
            )

            // 5. Baseline-relative
            row(
                "Baseline-relative",
                snapshot: snapshot, now: now, window: window,
                yRange: -2...2,
                channels: [
                    .init(label: "p", color: .red,   value: { $0.baselineRelative.pitch }),
                    .init(label: "r", color: .green, value: { $0.baselineRelative.roll })
                ]
            )

            // 6. Smoothed
            row(
                "Smoothed",
                snapshot: snapshot, now: now, window: window,
                yRange: -2...2,
                channels: [
                    .init(label: "p", color: .red,   value: { $0.smoothed.pitch }),
                    .init(label: "r", color: .green, value: { $0.smoothed.roll })
                ]
            )

            // 7. Shaped (post-tanh)
            row(
                "Shaped (consumers)",
                snapshot: snapshot, now: now, window: window,
                yRange: -1...1,
                channels: [
                    .init(label: "p", color: .red,   value: { $0.shaped.pitch }),
                    .init(label: "r", color: .green, value: { $0.shaped.roll })
                ]
            )

            // 8. Throttled output (NaN-padded — falls back to shaped on dropped frames)
            row(
                "Throttled output",
                snapshot: snapshot, now: now, window: window,
                yRange: -1...1,
                channels: [
                    .init(label: "p", color: .red,   value: { $0.throttledOutput?.pitch ?? .nan }),
                    .init(label: "r", color: .green, value: { $0.throttledOutput?.roll ?? .nan })
                ]
            )
        }
    }

    private func row(
        _ title: String,
        snapshot: MotionDebugViewModel.Snapshot,
        now: Date,
        window: TimeInterval,
        yRange: ClosedRange<Double>,
        channels: [MotionDebugSparkline.Channel]
    ) -> some View {
        MotionDebugSignalRow(
            title: title,
            latest: snapshot.latest,
            samples: snapshot.samples,
            referenceTime: now,
            windowDuration: window,
            yRange: yRange,
            channels: channels
        )
        Divider()
    }
}
```

> Note: `MotionDebugSparkline.Channel` is referenced by name above. Confirm during build that the Swift compiler resolves `.init(label:color:value:)` shorthand to `MotionDebugSparkline.Channel`. If not, replace with `MotionDebugSparkline.Channel(label: ..., color: ..., value: ...)` explicitly.

> Note 2: a NaN sample in the throttled-output row creates a gap in the line because `Path` rejects non-finite points. The `MotionDebugSparkline` `addLine(to:)` will simply not visit NaN coordinates, producing the desired gap-on-dropped-frame visualization.

> Note 3: `signalRows(snapshot:now:)` returns a `Group` whose contents include `Divider()` between rows via the helper. SwiftUI flattens this inside `LazyVStack` into one row per `MotionDebugSignalRow + Divider` pair.

- [ ] **Step 2: Build**

```bash
swift build 2>&1 | tail -15
```

Expected: success. If the `.init(label:...)` shorthand doesn't resolve, edit to use the fully qualified `MotionDebugSparkline.Channel(...)` and rebuild.

- [ ] **Step 3: Commit**

```bash
git add Packages/Sources/FeatureSettings/MotionDebug/MotionDebugScene.swift
git commit -m "$(cat <<'EOF'
feat(featuresettings): MotionDebugScene top-level surface

Subscribes to MotionService.debugSamples only while visible. Drives all
canvases from TimelineView(.animation) so SwiftUI re-evaluates at display
refresh. 8 signal rows (raw Euler / quaternion / gravity / normalized /
baseline-relative / smoothed / shaped / throttled) — quaternion is the
ground-truth reference that stays continuous through Euler-singularity
discontinuities.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Wire `.motionDebug` route into `SettingsSheet`

**Files:**
- Modify: `Packages/Sources/FeatureSettings/SettingsSheet.swift`

- [ ] **Step 1: Modify the file**

Apply these edits to `Packages/Sources/FeatureSettings/SettingsSheet.swift`:

**1a.** Replace the `Route` enum (currently `private enum Route: Hashable { case developer }`) with:

```swift
private enum Route: Hashable { case developer, motionDebug }
```

**1b.** Add `motionService` to the public init signature and stored property. After the existing `public let openSystemSettings: () -> Void` add:

```swift
    /// Optional MotionService injected by the host so the #if DEBUG motion
    /// debug screen can subscribe to `debugSamples`. nil hides the row.
    public let motionService: (any MotionService)?
```

**1c.** Add the parameter (with default `nil`) to `init(...)`. Append a parameter at the end of the existing parameter list:

```swift
        motionService: (any MotionService)? = nil
```

…and assign it in the body:

```swift
        self.motionService = motionService
```

**1d.** Extend the `navigationDestination` switch to handle `.motionDebug`:

```swift
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .developer:
                        DeveloperSettingsPanel(
                            onAddDebugRecords: onAddDebugRecords,
                            onAddNearbyDebugRecords: onAddNearbyDebugRecords,
                            onRemoveDebugRecords: onRemoveDebugRecords
                        )
                    case .motionDebug:
                        if let motionService {
                            MotionDebugScene(service: motionService)
                        } else {
                            Text("Motion service unavailable")
                        }
                    }
                }
```

**1e.** Add a `#if DEBUG` row to the Developer settings group. Replace the current `Developer` group:

```swift
            SettingsGroup(title: "Developer") {
                SettingsRow(label: "Developer settings", onTap: { path.append(.developer) }) {
                    trailingIcon(systemName: "chevron.right", size: 14, weight: .semibold)
                }
            }
```

with:

```swift
            SettingsGroup(title: "Developer") {
                SettingsRow(label: "Developer settings", onTap: { path.append(.developer) }) {
                    trailingIcon(systemName: "chevron.right", size: 14, weight: .semibold)
                }
                #if DEBUG
                SettingsDivider()
                SettingsRow(label: "Motion debug", onTap: { path.append(.motionDebug) }) {
                    trailingIcon(systemName: "chevron.right", size: 14, weight: .semibold)
                }
                #endif
            }
```

**1f.** Update the detent-on-route-change closure so `.motionDebug` also switches the sheet to `.large`:

```swift
        .onChange(of: path) { _, newPath in
            detent = newPath.contains(.developer) || newPath.contains(.motionDebug) ? .large : .medium
        }
```

- [ ] **Step 2: Build**

```bash
swift build 2>&1 | tail -10
```

Expected: build fails at the call sites in `RootScene` because the new (defaulted) parameter isn't supplied — actually the default `nil` keeps existing call sites compiling. So expected: build succeeds. If a call site somewhere passes `motionService:` positionally and breaks, we add the named arg in Task 12.

- [ ] **Step 3: Commit**

```bash
git add Packages/Sources/FeatureSettings/SettingsSheet.swift
git commit -m "$(cat <<'EOF'
feat(featuresettings): SettingsSheet adds .motionDebug route (#if DEBUG)

Optional motionService parameter (defaults to nil so existing call sites
keep compiling). New row only visible in DEBUG builds; pushes
MotionDebugScene onto the navigation stack and switches the sheet detent
to .large.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Wire `motionService` from `RootScene`

**Files:**
- Modify: `Packages/Sources/AppFeature/RootScene.swift`

- [ ] **Step 1: Modify the SettingsSheet call site**

In `Packages/Sources/AppFeature/RootScene.swift`, find the existing `.sheet(isPresented: $router.showingSettings)` block and add `motionService:` to the `SettingsSheet` initializer:

```swift
        .sheet(isPresented: $router.showingSettings) {
            SettingsSheet(
                onAbout: { router.showingAbout = true },
                onAddDebugRecords: addDebugRecords,
                onAddNearbyDebugRecords: addNearbyDebugRecords,
                onRemoveDebugRecords: removeDebugRecords,
                readLocationAuthorization: { environment.locationService.currentAuthorization() },
                requestLocationAuthorization: { await environment.locationService.requestAuthorization() },
                openSystemSettings: openSystemSettings,
                motionService: environment.motionService
            )
                .presentationCornerRadius(12)
        }
```

- [ ] **Step 2: Build for both targets**

```bash
swift build 2>&1 | tail -10
```

Expected: build succeeds.

```bash
xcodebuild build \
    -scheme CasualContacts \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    2>&1 | tail -10
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Packages/Sources/AppFeature/RootScene.swift
git commit -m "$(cat <<'EOF'
feat(appfeature): RootScene wires motionService into SettingsSheet

Production CoreMotionService is reused by the debug screen — same instance,
same stream, no parallel pipeline.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: End-to-end verification on simulator

**Files:**
- None (verification + screenshot/inspection only)

- [ ] **Step 1: Run host-side test pass**

```bash
cd /Users/adam/Projects/cc/.worktrees/motion-debug-screen/Packages
swift test 2>&1 | grep -E "All tests|tests? passed|✘|failed" | tail -10
```

Expected: "All tests passed". (The pre-existing `swiftpm-testing-helper signal 5` flake may still appear after the pass message — note in commit body if so; it's unrelated.)

- [ ] **Step 2: Build + install on iPhone 17 simulator**

```bash
cd /Users/adam/Projects/cc/.worktrees/motion-debug-screen
xcodebuild build \
    -scheme CasualContacts \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install "iPhone 17" \
    /Users/adam/Projects/cc/.worktrees/motion-debug-screen/CasualContacts/build/Debug-iphonesimulator/CasualContacts.app
xcrun simctl launch "iPhone 17" com.stacksdubeurre.CasualContacts
```

Expected: app launches.

- [ ] **Step 3: Drive the simulator to the debug screen**

Use `mcp__ios-simulator__ui_describe_all` to find the Settings entry point (gear icon or equivalent).

Drive the flow:
1. `mcp__ios-simulator__ui_tap` on the Settings button.
2. `mcp__ios-simulator__ui_describe_all` — verify the new "Motion debug" row appears under the Developer section.
3. `mcp__ios-simulator__ui_tap` on "Motion debug".
4. `mcp__ios-simulator__ui_describe_all` — verify "Motion Debug" navigation title and a list of signal rows ("Raw Euler (rad)", "Quaternion", "Gravity", "Normalized", "Baseline-relative", "Smoothed", "Shaped (consumers)", "Throttled output") all appear in the hierarchy.

If anything is missing or off-screen, debug from the hierarchy frames (per CLAUDE.md guidance).

- [ ] **Step 4: Visual sanity check**

Now use `mcp__ios-simulator__ui_view` (or `screenshot`) once to confirm the sparklines are actually rendering. Look for:
- Crosshair on the 2D dot.
- Numeric values to the left of each sparkline updating.
- Sparkline lines visible (the simulator's motion sensor is static — you'll see flat lines but they should render).

For real-motion verification, install on a physical device and tilt through vertical to observe the gimbal-lock signature in raw Euler vs. quaternion. (This is the primary purpose of the screen — but the simulator pass above is the gate for "the screen works".)

- [ ] **Step 5: No commit needed for verification.** If the verification revealed a bug, file the fix as a follow-up commit on this branch.

---

## Task 14: Final pass — README pointer, plan-doc-sync

**Files:**
- Modify: `CLAUDE.md` (add a brief "Motion debug screen" pointer under "Common workflows" or "Outstanding work")

- [ ] **Step 1: Append a short note to `CLAUDE.md`**

Find the "Common workflows" section in `/Users/adam/Projects/cc/.worktrees/motion-debug-screen/CLAUDE.md` and append a new subsection:

```markdown
### Inspect the motion pipeline live (DEBUG only)

Settings → "Motion debug" exposes raw Euler, quaternion, gravity, every
intermediate stage of the CoreMotion pipeline, and the throttled output
as live numerics + 10 s sparklines. Use it to investigate gimbal-lock
behavior near vertical or any other discontinuity in the signal.
Disposable — gets removed once the pipeline-fix spec lands.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: pointer to the motion debug screen

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Hand off to `superpowers:finishing-a-development-branch`** for merge / PR options.

---

## Self-Review

**Spec coverage:**

| Spec section | Task(s) |
|---|---|
| §1 Goals & non-goals | implicit (every task is non-tuning, non-recording, `#if DEBUG`) |
| §2 Architecture & wiring (side-channel stream, same callback, no parallel pipeline) | T2, T5 |
| §2 Module placement | T1 (CoreModels), T5 (Services), T3/T4 (test support + screenshot), T6–T11 (FeatureSettings) |
| §3 `MotionDebugSample` data model | T1 |
| §4 Pinned region (2D dot, state chips) | T9 |
| §4 Scrolling list with 8 specific signal rows | T8, T10 |
| §4 Sparkline implementation (Canvas, ring buffer, TimelineView) | T6, T7, T10 |
| §4 Access — Settings row, `#if DEBUG` | T11 |
| §5 Testing strategy (sample round-trip, debugSamples never-yielding on fakes, view-model unit tests, no view-snapshot tests) | T1, T3, T6 |
| §6 Reduce Motion banner | **GAP** — see fix below |
| §7 Risks (perf — gate behind `#if DEBUG`) | T5 |
| §7 Pre-existing flake noted | T13 step 1 |

**Gap fix — Reduce Motion banner.** §6 of the spec calls for a banner when `UIAccessibility.isReduceMotionEnabled` is true so the developer doesn't think the screen is broken (the production stream short-circuits in that case and `debugSamples` never fires). Add this to Task 10 as an extra modifier.

Insert this `@State` and the banner overlay inside `MotionDebugScene`:

```swift
    @State private var reduceMotionActive = false
```

…and at the top of the scrolling content, conditionally render:

```swift
                    if reduceMotionActive {
                        Text("Reduce Motion is on — debug stream is suppressed.")
                            .font(.caption)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(.orange.opacity(0.2))
                    }
```

…and read the OS state in `.task`:

```swift
        .task {
            #if os(iOS)
            reduceMotionActive = UIAccessibility.isReduceMotionEnabled
            #endif
            for await sample in service.debugSamples {
                viewModel.append(sample)
            }
        }
```

(Add `import UIKit` at the top of `MotionDebugScene.swift`, gated `#if canImport(UIKit)`.)

**Apply this gap fix as part of Task 10.**

**Placeholder scan:** none. All steps contain concrete code or commands.

**Type consistency:**

- `MotionService.debugSamples`, `MotionDebugSample`, `MotionDebugViewModel.Snapshot.{samples, latest}`, `MotionDebugSparkline.Channel.{label, color, value}` consistent across T2–T10. ✓
- `viewModel.append(_:)` and `viewModel.snapshot()` and `viewModel.emissionRate(referenceTime:)` consistent in T6 → T10. ✓
- `Route.{developer, motionDebug}` consistent in T11. ✓
- `secondsSinceSettleReset` is the field name in both T1 (definition), T5 (population), and T9 (consumption). ✓

**Scope:** single disposable screen, no pipeline modification. Single plan, no decomposition needed.

**Ambiguity:** all design decisions (Hz computed in view-model, NaN-as-gap for dropped throttle, banner for Reduce Motion, settle countdown in chip) are explicit.

Plan is internally consistent and matches the spec.
