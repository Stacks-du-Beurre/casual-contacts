# CardView perf — deferred wins

Status: research / not implemented
Date: 2026-04-20
Context: landed on branch `perf/improvements` alongside the formatter hoist, `.equatable()` splits, and backdrop dedup. These two items were deferred because they need device-level validation before we can commit to an approach.

## #5 — Throttle / coalesce motion updates

### What we have today

`CoreMotionService` (`Packages/Sources/Services/CoreMotionService.swift:82`) configures `deviceMotionUpdateInterval = 1.0 / 60.0` and yields a smoothed/rebased `DeviceAttitude` into an `AsyncStream<DeviceAttitude>` on every CoreMotion callback. `RootScene` (`Packages/Sources/AppFeature/RootScene.swift:64`) awaits that stream and writes each value into `@State currentAttitude`, propagating the change to every `CardView` on screen at 60 Hz.

Every row in the list re-evaluates its `body` on each tick. `CardView.body` rebuilds `backdrop()` (gradient + guilloche + constellation), `ornaments()` (moon + zodiac figure), and `CardTextLayer` (now with `.equatable()` shortcuts on the static overlays). The attitude-reactive surfaces — `HologramText`, `HolographicZodiac`, `GradientLayer` transfusion, `GuillocheRotationLayer` — evaluate their attitude-bound modifiers per tick.

### The win

- A list of N visible cards at 60 Hz does 60 × N per-card evaluations + 60 × N compositing passes per second.
- Halving the publish rate to 30 Hz halves the CPU. SwiftUI + CoreAnimation will interpolate between samples during the gap, so the visual difference at 30 Hz is small relative to the savings.
- For the `reduceMotion` path we should publish `.zero` once and stop forever — there's no reason to keep pumping the stream in reduced-motion mode.

### Approach

1. **Publish-side throttle in `CoreMotionService`** — track the last emitted timestamp and skip `continuation.yield` if `now - lastEmitted < targetInterval`. Default `targetInterval = 1.0 / 30.0`. Keep the internal smoother running at 60 Hz so low-pass quality is preserved; only the downstream emit rate changes.
2. **Adaptive rate** — when `abs(shaped.pitch)` and `abs(shaped.roll)` are both below the existing `movementThreshold`, drop the publish rate further (10–15 Hz) since there's no visual motion worth the work. Restore 30 Hz as soon as either axis crosses the threshold.
3. **Reduce-motion shortcut** — in `RootScene.onReceive(reduceMotionStatusDidChangeNotification)` already sets `currentAttitude = .zero` when enabled. Also teach `CoreMotionService.start()` to early-return `.zero` once and not register CoreMotion callbacks at all when `UIAccessibility.isReduceMotionEnabled`. Removes a whole 60 Hz CallBack thread during the accessibility path.
4. **Don't animate off-screen cards** — a list-level optimization: subscribe to the motion stream only when the list has visible rows. `List` already does row virtualization, but the `@State currentAttitude` at the root propagates to all rows regardless of visibility. Considerable work; punt unless profiling says it matters.

### Tradeoffs & risks

- 30 Hz is perceptibly less smooth than 60 Hz on a side-by-side test if you stare at it. Users moving the phone with intent may notice.
- Adaptive rate introduces a rate-change moment that can look like a micro-stutter if the threshold transition is poorly tuned. Needs hysteresis (threshold-up slightly higher than threshold-down) and probably easing across the rate change.
- The `CoreMotionSmoothing` filter is tuned against 60 Hz input. If we ever want to *internally* drop the sample rate for power savings, retune the filter constants; otherwise leave internal sampling at 60 Hz and only throttle the output.

### Validation plan

- Add an XCTest measurement (Instruments-driven, not swift-test) that scripts a 10-second scroll over a list of 20 cards under `os_signpost` bounds around each body evaluation. Compare mean body-eval-count per second between baseline and throttled builds.
- Side-by-side video capture on device (iPhone 17 Pro): record the current card with fixed gyro input at 60 Hz vs 30 Hz playback, then frame-diff. Any perceptible difference shows up as non-zero per-frame pixel delta.
- Verify `reduceMotionEnabled` path on the simulator by toggling `AX Inspector → Reduce Motion` and confirming zero `startDeviceMotionUpdates` callbacks in a logged baseline.

### Estimated effort

~1 day. Throttle + adaptive rate + reduce-motion shortcut + new tests. No UI changes, so low regression risk.

---

## #6 — `.drawingGroup()` on the static guilloche layer

### What we have today

Each card renders a guilloche pattern that's **attitude-independent** (`GuillocheBlendLayer` — composed path-fill, no attitude reads) plus **attitude-dependent** overlays (`GuillocheRotationLayer` reads `attitude.roll` for a rotation, `HologramText`/`HolographicZodiac` read attitude for translation/rotation, `GradientLayer.transfusionOpacity(for: attitude)` for a blend opacity).

The guilloche blend paths are many (`*130 generated files*`), each containing up to ~16 Path strokes. On every body tick, SwiftUI walks the whole backdrop hierarchy to validate structure, and on every render it rasterizes the whole backdrop onto CA layers from scratch. Even if inputs haven't changed, the rasterization cost is paid per frame.

### The win

`.drawingGroup()` forces Metal/CA to rasterize a subview into a single offscreen texture, cached on the GPU. When the inputs to that subview don't change, subsequent frames composite the cached texture instead of re-rasterizing. For a 60 Hz animation where only the overlay on top of a static background changes, this is a classic SwiftUI optimization — move the static background into its own `drawingGroup`, leave the reactive overlays outside.

### Proposed split

- **Inside drawing group (static per record/size)**: `GuillocheBlendLayer` + `CardBackdrop`'s non-attitude parts. Need to *hoist* these into a dedicated static subview keyed on `(record.id, size)` so SwiftUI's cache invalidates only when the record or size changes.
- **Outside drawing group (attitude-reactive)**: `GradientLayer`'s transfusion (blends over the static), `GuillocheRotationLayer` (rotates with roll), `HologramText`, `HolographicZodiac`, `MoonPhaseLayer` animations, the constellation `ZodiacLayer` with motion.

### Caveats

1. `drawingGroup()` disables some SwiftUI features inside the group (e.g., blend modes that depend on the compositor above it). The current card heavily uses `.blendMode(.lighten)`, `.blendMode(.luminosity)`, `.blendMode(.overlay)` — if any of these need to sample *through* the static layer, they can't run inside the group. Must be layered *above* the drawing group.
2. `drawingGroup()` allocates an offscreen render target. For a list of 20 cards, that's 20 separate textures cached on the GPU. On older devices (pre-A14) memory pressure could force eviction, negating the win. iPhone 17 Pro isn't at risk but iPhone SE 2 might be.
3. Text inside a drawing group rasterizes at the current resolution — zooming via Dynamic Type must force cache invalidation. `drawingGroup(opaque:colorMode:)` does key on environment changes, but the reliability of that is worth confirming on-device.
4. Snapshot tests (`CardSnapshotTests`, `DynamicTypeSnapshotTests`) may pixel-diff slightly due to drawingGroup's rasterization boundary (antialias seams at layer edges). Baselines may need re-recording.

### Approach

1. Extract a `StaticCardBackground(record: Record, size: CGSize): View` struct containing only the attitude-independent parts of `backdrop()` and `CardBackdrop`'s inner static composition. This is a significant refactor — `CardBackdrop` currently weaves static + attitude content in one ZStack. Splitting requires auditing every child for `attitude` reads.
2. Apply `.drawingGroup()` (or `.drawingGroup(opaque: false, colorMode: .linear)` if color accuracy matters for blend modes) to the `StaticCardBackground` at its use site in `CardView.body`.
3. Layer attitude-reactive content ABOVE the drawing group (not inside), preserving the existing blend-mode stack on top of the rasterized cache.
4. Guard with `#if !targetEnvironment(simulator)` initially — `drawingGroup` in the simulator can behave differently than on device, so ship the flag off by default and validate on real hardware first.

### Validation plan

- Instruments → Metal System Trace on a list of 20 cards scrolling. Measure GPU time per frame before/after. Look for reduction in the gradient + guilloche draw calls specifically.
- Instruments → Core Animation → FPS & frame hitches. Baseline vs. drawingGroup should both hit 60 Hz (iPhone 17 Pro has plenty of headroom). The win shows up on 120 Hz ProMotion or on thermal-throttled devices — test with `XCDeviceCondition` thermal state = serious.
- Re-record `CardSnapshotTests` and `DynamicTypeSnapshotTests`; pixel-diff expected to be <1% per snapshot. If >1%, investigate whether `drawingGroup` changed antialiasing.

### Estimated effort

~3–5 days. The refactor of `CardBackdrop` to cleanly separate static from attitude-reactive content is the bulk of it; the `drawingGroup` application itself is one modifier.

---

## Ordering

Do **#5 first**. It's cheaper, less risky, and the win is measurable with the existing `swift test` harness plus a single Instruments session. `#6` needs a backdrop refactor and real on-device frame profiling — defer until we have a user-reported perf complaint or a target device (iPhone SE 2, thermal-throttled iPhone 17) where the current render is shown to miss frame budget.
