# Motion Debug Screen — Design

**Status:** approved 2026-04-26
**Branch:** `plan/motion-debug-screen`
**Successor:** a follow-up spec will design the actual pipeline fix once this screen makes the failure modes legible.

## 1. Goals & non-goals

### Goal

Build a debug-only screen that exposes every stage of the CoreMotion → `DeviceAttitude` pipeline live, so we can directly observe what the signal looks like at the edges (gimbal lock near vertical, fast tilts, post-`tanh` saturation) and decide on a remediation strategy from evidence rather than intuition.

The motivating symptom: when the phone is held nearly vertical, animations "go crazy" — `CMAttitude.pitch/roll` Euler angles pass through a singularity at pitch ≈ ±π/2 where roll and yaw can flip 180° instantaneously. The current pipeline (`CoreMotionService.swift`: baseline-subtract → low-pass α=0.1 → `tanh` → throttle) cannot repair a discontinuity — the smoother eases through wrong intermediate values.

### Non-goals

- **No live tuning controls.** Read-only screen.
- **No recording/export.** Visual-only.
- **No fix to the pipeline itself.** That is the next spec, informed by what this one shows.
- **Not shipped to release.** `#if DEBUG` only.
- **Disposable.** Removed once the pipeline fix lands. Clarity > craft.

## 2. Architecture & data flow

### Wiring (chosen approach)

`MotionService` gains an optional **side-channel debug stream**. The production `attitude` stream is unchanged — consumers (`CardView`, `EmptyStateGradientBackdrop`, etc.) continue to receive the throttled, shaped output as today. The debug stream is populated by the same `CMMotionManager` callback inside `CoreMotionService` that already powers the production pipeline, so the debug screen sees *exactly* the values the rest of the app is using — no parallel pipeline, no drift.

```
CMMotionManager 60 Hz
        │
        ▼
┌──────────────────── CoreMotionService callback ────────────────────┐
│                                                                    │
│  raw Euler ──▶ raw quaternion ──▶ gravity                          │
│       │                                                            │
│       ▼                                                            │
│  normalized (÷ π/2)                                                │
│       │                                                            │
│       ▼                                                            │
│  baseline-relative                                                 │
│       │                                                            │
│       ▼                                                            │
│  low-pass smoothed                                                 │
│       │                                                            │
│       ▼                                                            │
│  tanh-shaped                                                       │
│       │                                                            │
│       ▼                                                            │
│  throttle ──▶ attitude AsyncStream  (production, unchanged)        │
│       │                                                            │
│       └──────▶ MotionDebugSample ──▶ debugSamples AsyncStream     │
│                  (every callback;                                  │
│                   carries every stage above + state markers)      │
└────────────────────────────────────────────────────────────────────┘
```

### Module placement

- `CoreModels`
  - `MotionDebugSample` — pure value type carrying every stage of the pipeline plus state markers. No framework deps.
  - `MotionService` protocol — gains `var debugSamples: AsyncStream<MotionDebugSample> { get }`. Optional from a usage standpoint, but always present on the protocol for compile-time clarity; fakes return a never-yielding stream.
- `Services`
  - `CoreMotionService` — yields a `MotionDebugSample` per CoreMotion callback alongside the existing throttled production yield.
- `ServicesTestSupport`
  - `StaticMotionService` — yields a never-emitting debug stream (or a fixture sample) to keep host-side tests deterministic.
- `AppFeature`
  - `MotionDebugScene` — the debug screen itself. Subscribes to `debugSamples` only while visible.
  - Settings row (`#if DEBUG`) wires presentation.

### Lifecycle

The debug stream is "always on" from `CoreMotionService`'s perspective — it yields one sample per CoreMotion callback regardless of whether anyone subscribes. Cost is one struct allocation + one continuation yield per frame at 60 Hz, on a callback that already exists. Negligible.

The debug screen subscribes via `for await sample in service.debugSamples` inside a `.task` modifier; SwiftUI cancels the task when the screen disappears.

The CoreMotion callback hosts both yields. Reduce Motion bypass logic in `CoreMotionService.start()` is preserved: when Reduce Motion is on, neither stream emits beyond the initial `.zero` (production) / no debug samples.

## 3. Data model — `MotionDebugSample`

Single immutable struct carrying every signal we want to expose. All `Double` unless noted.

```swift
public struct MotionDebugSample: Hashable, Sendable {
    public let timestamp: Date

    // Stage 0 — raw sources, untouched
    public let rawEulerPitch: Double      // radians
    public let rawEulerRoll: Double       // radians
    public let rawEulerYaw: Double        // radians
    public let rawQuaternion: SIMD4<Double>  // (x, y, z, w)
    public let gravity: SIMD3<Double>        // (x, y, z), unit vector

    // Stage 1 — normalized to ±1-ish via ÷ (π/2)
    public let normalizedPitch: Double
    public let normalizedRoll: Double

    // Stage 2 — baseline + baseline-relative
    public let baseline: DeviceAttitude               // current effective baseline (post-rebase ease)
    public let baselineRelative: DeviceAttitude       // normalized − baseline

    // Stage 3 — smoothed (post low-pass)
    public let smoothed: DeviceAttitude

    // Stage 4 — shaped (post tanh)
    public let shaped: DeviceAttitude

    // Stage 5 — final throttled value (nil if this callback was throttle-dropped)
    public let throttledOutput: DeviceAttitude?

    // State markers
    public let secondsSinceSettleReset: TimeInterval  // counts up; resets when movement crosses threshold
    public let isRebaseInProgress: Bool
    public let rebaseProgress: Double                 // 0...1 when in progress, else 0
}
```

## 4. UI — `MotionDebugScene`

Single dense scrolling screen. No tabs.

### Pinned top region (~30% of viewport)

- **2D pitch×roll dot.** Square aspect, gridlined unit-square, dot showing current `shaped.pitch` (x) × `shaped.roll` (y). Origin at center, ±1 at edges. A faint trail of the last ~1s gives motion direction at a glance.
- **State row.** Three small chips:
  - `settle`: countdown remaining of the 3.5s settle window (`max(0, 3.5 − secondsSinceSettleReset)`), colored when armed.
  - `rebase`: idle / in-progress with `rebaseProgress` as a thin bar.
  - `Hz`: rolling estimated emission rate of the production stream over the last 1 s, computed in the view-model by counting samples where `throttledOutput != nil`. Not carried in `MotionDebugSample` itself.

### Scrolling list region

Stacked rows, ~80pt tall each. From top to bottom (this order matters — vertical scanning of strips reveals where the discontinuity enters):

1. **Raw Euler — pitch / roll / yaw** (one row, three sparklines stacked thin, shared y-scale ±π)
2. **Quaternion x / y / z / w** (one row, four sparklines, shared y-scale −1…1) — *the reference for "did this orientation actually change continuously?"*
3. **Gravity x / y / z** (one row, three sparklines, shared y-scale −1…1)
4. **Normalized pitch / roll** (one row, two sparklines, ±2)
5. **Baseline-relative pitch / roll** (one row, two sparklines, ±2)
6. **Smoothed pitch / roll** (one row, two sparklines, ±2)
7. **Shaped pitch / roll** (one row, two sparklines, ±1) — what consumers actually receive
8. **Throttled output pitch / roll** (one row, two sparklines, ±1, gaps where dropped) — last-mile signal

Each row layout:

```
┌─────────────────────────────────────────────────────────────┐
│ Label              p: +0.123                                │
│ (signal name)      r: −0.456    [ rolling sparkline 10 s ]  │
│                    y: +0.789                                │
└─────────────────────────────────────────────────────────────┘
```

Numerics on the left in a fixed-width column; sparkline takes the remaining width. Sparkline shows the last 10 seconds at a fixed time-base (so visual width corresponds linearly to time, regardless of sample count).

### Sparkline implementation

`SwiftUI.Canvas` driven by a ring buffer of the last N samples per signal (N = 10 s × 60 Hz = 600 samples, comfortably small). The buffer lives in a `@Observable` view-model on the screen; one `Path` per channel per row, rebuilt from the buffer each animation frame. No per-sample SwiftUI invalidation — the view-model coalesces sample arrival with `CADisplayLink` (or `TimelineView(.animation)`) so the strips redraw at display refresh rather than on every sample.

### Access

Settings → "Motion debug" row, gated to `#if DEBUG`. Tapping pushes `MotionDebugScene` onto the navigation stack.

## 5. Testing strategy

The debug screen itself is throwaway, so we don't blanket it in tests. We do test the *contract* between the screen and the rest of the system, because that contract survives the screen's removal:

- **`MotionDebugSample` round-trips and equality.** Pure-value test in `CoreModelsTests`.
- **`StaticMotionService.debugSamples` does not crash and is never-yielding (or yields a deterministic fixture).** Unit test in `ServicesTestSupportTests`.
- **`CoreMotionService` yields exactly one `MotionDebugSample` per inbound CoreMotion callback, with `throttledOutput == nil` on dropped frames and `== shaped` on emitted frames.** Test by injecting a fake callback driver — no `CMMotionManager` required. (If injection is too invasive, fall back to an iOS-simulator-gated test that drives `start()` and asserts the debug stream produces samples; preferred path is host-side.)
- **No production behavior change.** Existing motion tests must still pass unchanged. The debug stream is purely additive.
- **No new visual snapshot tests.** The screen is debug-only and disposable; pixel-locking it would slow iteration without protecting anything that ships.

## 6. Accessibility

Debug-only, `#if DEBUG`, never reaches release or TestFlight, never reaches a user. We deliberately skip Dynamic Type, VoiceOver labeling, Reduce Motion adaptation of the sparklines, and Reduce Transparency. (The underlying `CoreMotionService` Reduce Motion bypass continues to apply: with Reduce Motion on, no debug samples flow. We should display a banner in the screen when this state is detected so the developer doesn't think the screen is broken.)

## 7. Risks & mitigations

- **Performance regression in production.** One extra struct alloc + continuation yield per CoreMotion callback at 60 Hz is the only added cost on the hot path. Mitigation: benchmark before/after with an empty subscriber; if measurable, gate *the yield call* (not the type) behind `#if DEBUG` inside `CoreMotionService`. The `MotionDebugSample` type stays in `CoreModels` unconditionally so the protocol shape is the same in release builds — debug builds populate the stream, release builds leave it never-yielding.
- **Screen lies about the production signal.** Mitigated by construction: the debug sample is built from the *same* intermediate variables in the *same* callback that produces the throttled output. There is no second pipeline.
- **Pre-existing test flake.** `swift test` on this checkout intermittently exits with signal 5 after "All tests passed" — present on `main` too. Not introduced here; out of scope.

## 8. Out of scope (for the eventual fix spec, not this one)

- Quaternion-based attitude pipeline.
- Discontinuity-rejecting filter (e.g., reject samples where `‖raw_t − raw_{t-1}‖` exceeds a kinematic budget).
- Gimbal-aware Euler reconstruction from gravity.
- Live-tunable smoothing parameters.
- Recording / CSV export for offline analysis.

These are the directions the debug screen exists to inform. None are decided here.
