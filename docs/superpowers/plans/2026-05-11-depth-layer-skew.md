# Depth Layer Skew Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a subtle, tunable affine skew to the existing guilloche depth-layer motion so the stack reads more like a tilted 3D scene instead of flat layers sliding in x/y.

**Architecture:** Keep the current translation/depth pipeline intact. Add a reusable skew calculation beside the existing `depthOffset` helpers, then apply it only to the `GuillocheBlendLayer` path geometry for the first evaluation pass. Do not switch to true SwiftUI 3D transforms yet; that is higher risk for clipping, blend modes, and snapshot churn.

**Tech Stack:** Swift 6, SwiftUI `Path`, `CGAffineTransform`, Swift Testing.

---

## Scope

Initial implementation should affect the guilloche blend path stack only. Moon phase, zodiac glyph, and constellation already use depth offsets, but this first pass should not skew those ornaments until the guilloche behavior feels right on device.

The effect must be tunable from the existing Developer Settings panel:

- Developer toggle: `Enable depth skew`
- Default toggle state: `false`
- Default skew amount: `0.08`
- Range: `0.0...0.2`
- Toggle off means the current translation-only behavior, regardless of skew amount.
- Toggle on with `0.0` skew amount also means the current translation-only behavior.

No generated guilloche files, asset files, or Figma assets should be touched.

## Files

- Modify: `Packages/Tests/VisualsTests/GuillocheBlendLayerTests.swift`
  - Adds red tests for skew identity, depth scaling, reverse depth order, reverse motion direction, and path-center preservation.
- Modify: `Packages/Tests/VisualsTests/CardElementDepthTuningTests.swift`
  - Adds red tests for the new persisted `isSkewEnabled` and `skewAmount` tuning.
- Modify: `Packages/Sources/Visuals/Layers/CardElementDepthTuning.swift`
  - Adds persisted `isSkewEnabled` and `skewAmount` defaults and reset behavior.
- Modify: `Packages/Sources/Visuals/Layers/GuillocheBlendLayer.swift`
  - Adds skew amount input, skew math helpers, and path application.
- Modify: `Packages/Sources/Visuals/CardBackdrop.swift`
  - Passes `elementDepthTuning.skewAmount` into `GuillocheBlendLayer` only when `elementDepthTuning.isSkewEnabled` is true.
- Modify: `Packages/Sources/FeatureSettings/DeveloperSettingsPanel.swift`
  - Adds an “Enable depth skew” toggle and a “Depth skew amount” slider below “Depth perspective amount”.

## Task 1: Red Tests For Skew Math

**Files:**
- Modify: `Packages/Tests/VisualsTests/GuillocheBlendLayerTests.swift`

- [ ] **Step 1: Add failing tests**

Append these tests before `layerInstantiatesAtEveryDensity`:

```swift
@Test func depthSkewTransformKeepsFlatAndAnchoredLayersIdentity() {
    let tilted = DeviceAttitude(pitch: 0.6, roll: -0.4)

    let flat = GuillocheBlendLayer.depthSkewTransform(
        layer: 15,
        attitude: .zero,
        skewAmount: 0.08
    )
    let anchored = GuillocheBlendLayer.depthSkewTransform(
        layer: 0,
        attitude: tilted,
        skewAmount: 0.08
    )
    let disabled = GuillocheBlendLayer.depthSkewTransform(
        layer: 15,
        attitude: tilted,
        skewAmount: 0
    )

    #expect(flat == .identity)
    #expect(anchored == .identity)
    #expect(disabled == .identity)
}

@Test func depthSkewTransformScalesWithLayerDepth() {
    let attitude = DeviceAttitude(pitch: 0.5, roll: 0.5)
    let skewAmount = 0.08

    let layer5 = GuillocheBlendLayer.depthSkewTransform(
        layer: 5,
        attitude: attitude,
        skewAmount: skewAmount
    )
    let layer15 = GuillocheBlendLayer.depthSkewTransform(
        layer: 15,
        attitude: attitude,
        skewAmount: skewAmount
    )

    #expect(abs(layer5.b) < abs(layer15.b))
    #expect(abs(layer5.c) < abs(layer15.c))
    #expect(layer15.b == CGFloat(attitude.pitch) * CGFloat(skewAmount))
    #expect(layer15.c == CGFloat(attitude.roll) * CGFloat(skewAmount))
}

@Test func depthSkewTransformCarriesDepthAndMotionReversal() {
    let attitude = DeviceAttitude(pitch: 0.5, roll: -0.5)
    let normal = GuillocheBlendLayer.depthSkewTransform(
        layer: 15,
        attitude: attitude,
        skewAmount: 0.08
    )
    let reversedMotion = GuillocheBlendLayer.depthSkewTransform(
        layer: 15,
        attitude: attitude,
        reverseMotionDirection: true,
        skewAmount: 0.08
    )
    let reversedDepthNear = GuillocheBlendLayer.depthSkewTransform(
        layer: 0,
        attitude: attitude,
        reverseDepthOrder: true,
        skewAmount: 0.08
    )
    let reversedDepthFar = GuillocheBlendLayer.depthSkewTransform(
        layer: 15,
        attitude: attitude,
        reverseDepthOrder: true,
        skewAmount: 0.08
    )

    #expect(reversedMotion.b == -normal.b)
    #expect(reversedMotion.c == -normal.c)
    #expect(reversedDepthNear.b == normal.b)
    #expect(reversedDepthNear.c == normal.c)
    #expect(reversedDepthFar == .identity)
}

@Test func centeredSkewTransformPreservesPathCenter() {
    let rect = CGRect(x: 10, y: 20, width: 100, height: 80)
    let transform = GuillocheBlendLayer.centeredSkewTransform(
        bounds: rect,
        skew: CGAffineTransform(a: 1, b: 0.04, c: -0.03, d: 1, tx: 0, ty: 0)
    )
    let center = CGPoint(x: rect.midX, y: rect.midY)

    #expect(center.applying(transform).x == center.x)
    #expect(center.applying(transform).y == center.y)
}
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
cd /Users/adam/Projects/cc/Packages
swift test --filter GuillocheBlendLayerTests
```

Expected: compile failure because `depthSkewTransform` and `centeredSkewTransform` do not exist yet.

## Task 2: Red Tests For Skew Tuning Persistence

**Files:**
- Modify: `Packages/Tests/VisualsTests/CardElementDepthTuningTests.swift`

- [ ] **Step 1: Add failing tests**

Update existing expectations to include `isSkewEnabled` and `skewAmount`:

```swift
#expect(tuning.isSkewEnabled == false)
#expect(tuning.skewAmount == 0.08)
#expect(CardElementDepthTuning.Defaults.skewAmountMin == 0.0)
#expect(CardElementDepthTuning.Defaults.skewAmountMax == 0.2)
```

In `writesPersistAcrossInstances`, add:

```swift
first.isSkewEnabled = true
first.skewAmount = 0.12
#expect(second.isSkewEnabled == true)
#expect(second.skewAmount == 0.12)
```

In `resetRestoresDefaults`, add:

```swift
tuning.isSkewEnabled = true
tuning.skewAmount = 0.2
#expect(tuning.isSkewEnabled == false)
#expect(tuning.skewAmount == 0.08)
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
cd /Users/adam/Projects/cc/Packages
swift test --filter CardElementDepthTuningTests
```

Expected: compile failure because `isSkewEnabled`, `skewAmount`, and skew defaults do not exist yet.

## Task 3: Add Skew Tuning

**Files:**
- Modify: `Packages/Sources/Visuals/Layers/CardElementDepthTuning.swift`

- [ ] **Step 1: Implement minimal tuning state**

Add defaults:

```swift
public static let isSkewEnabled: Bool = false
public static let skewAmount: Double = 0.08
public static let skewAmountMin: Double = 0.0
public static let skewAmountMax: Double = 0.2
```

Add keys:

```swift
static let isSkewEnabled = "CardElementDepthTuning.isSkewEnabled"
static let skewAmount = "CardElementDepthTuning.skewAmount"
```

Add properties:

```swift
public var isSkewEnabled: Bool {
    didSet { defaults.set(isSkewEnabled, forKey: Key.isSkewEnabled) }
}
```

```swift
public var skewAmount: Double {
    didSet { defaults.set(skewAmount, forKey: Key.skewAmount) }
}
```

Initialize them:

```swift
self.isSkewEnabled = Self.read(defaults, Key.isSkewEnabled, fallback: Defaults.isSkewEnabled)
```

```swift
self.skewAmount = Self.read(defaults, Key.skewAmount, fallback: Defaults.skewAmount)
```

Reset them:

```swift
isSkewEnabled = Defaults.isSkewEnabled
```

```swift
skewAmount = Defaults.skewAmount
```

- [ ] **Step 2: Add Bool defaults reader**

Add:

```swift
private static func read(_ defaults: UserDefaults, _ key: String, fallback: Bool) -> Bool {
    defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
}
```

- [ ] **Step 3: Run tuning tests and verify GREEN**

Run:

```bash
cd /Users/adam/Projects/cc/Packages
swift test --filter CardElementDepthTuningTests
```

Expected: `CardElementDepthTuningTests` pass.

## Task 4: Add Skew Math Helpers

**Files:**
- Modify: `Packages/Sources/Visuals/Layers/GuillocheBlendLayer.swift`

- [ ] **Step 1: Extract reusable normalized depth**

Refactor `perspectiveDepth(...)` so both translation and skew use the same depth curve:

```swift
nonisolated private static func perspectiveDepthFraction(
    layer: Int,
    maxLayer: Int,
    reverseDepthOrder: Bool,
    perspectiveAmount: Double
) -> CGFloat {
    guard maxLayer > 0 else { return 0 }

    let clampedLayer = min(max(layer, 0), maxLayer)
    let effectiveLayer = reverseDepthOrder ? maxLayer - clampedLayer : clampedLayer
    guard effectiveLayer > 0 else { return 0 }

    let t = CGFloat(effectiveLayer) / CGFloat(maxLayer)
    let z = t * perspectiveMaxZ
    let projected = z / max(perspectiveCameraDistance - z, .leastNonzeroMagnitude)
    let maxProjected = perspectiveMaxZ / (perspectiveCameraDistance - perspectiveMaxZ)
    let perspectiveNormalized = projected / maxProjected
    let perspectiveDelta = perspectiveNormalized - t
    return max(0, t + perspectiveDelta * CGFloat(max(0, perspectiveAmount)))
}
```

Then make `perspectiveDepth(...)` call it:

```swift
let normalized = perspectiveDepthFraction(
    layer: layer,
    maxLayer: maxLayer,
    reverseDepthOrder: reverseDepthOrder,
    perspectiveAmount: perspectiveAmount
)
return normalized * CGFloat(maxLayer) * depthScale
```

- [ ] **Step 2: Add the public skew helpers**

Add:

```swift
nonisolated public static func depthSkewTransform(
    layer: Int,
    attitude: DeviceAttitude,
    maxLayer: Int = GuillocheBlendLayer.defaultMaxDepthLayer,
    reverseDepthOrder: Bool = false,
    reverseMotionDirection: Bool = false,
    perspectiveAmount: Double = 1.0,
    skewAmount: Double = 0.08
) -> CGAffineTransform {
    let normalized = perspectiveDepthFraction(
        layer: layer,
        maxLayer: maxLayer,
        reverseDepthOrder: reverseDepthOrder,
        perspectiveAmount: perspectiveAmount
    )
    guard normalized > 0, skewAmount > 0 else { return .identity }

    let direction: CGFloat = reverseMotionDirection ? -1 : 1
    let pitchSkew = direction * CGFloat(attitude.pitch) * normalized * CGFloat(skewAmount)
    let rollSkew = direction * CGFloat(attitude.roll) * normalized * CGFloat(skewAmount)
    guard pitchSkew != 0 || rollSkew != 0 else { return .identity }

    return CGAffineTransform(a: 1, b: pitchSkew, c: rollSkew, d: 1, tx: 0, ty: 0)
}

nonisolated public static func centeredSkewTransform(
    bounds: CGRect,
    skew: CGAffineTransform
) -> CGAffineTransform {
    guard !bounds.isNull, !bounds.isEmpty, skew != .identity else { return skew }

    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    return CGAffineTransform(translationX: center.x, y: center.y)
        .concatenating(skew)
        .concatenating(CGAffineTransform(translationX: -center.x, y: -center.y))
}
```

If `centeredSkewTransformPreservesPathCenter` fails, fix the concatenation order before moving on. Do not adjust the test to match a moving center.

- [ ] **Step 3: Run skew tests and verify GREEN**

Run:

```bash
cd /Users/adam/Projects/cc/Packages
swift test --filter GuillocheBlendLayerTests
```

Expected: `GuillocheBlendLayerTests` pass.

## Task 5: Apply Skew To Guilloche Blend Paths

**Files:**
- Modify: `Packages/Sources/Visuals/Layers/GuillocheBlendLayer.swift`
- Modify: `Packages/Sources/Visuals/CardBackdrop.swift`

- [ ] **Step 1: Add `skewAmount` to `GuillocheBlendLayer`**

Add stored property:

```swift
public let skewAmount: Double
```

Add init parameter after `perspectiveAmount`:

```swift
skewAmount: Double = 0.08,
```

Assign it:

```swift
self.skewAmount = skewAmount
```

- [ ] **Step 2: Apply centered path skew in `body`**

Inside the `ForEach`, compute the same layer step used for offset, then transform the path before stroking:

```swift
let path = paths[index]
let maxLayer = max(paths.count - 1, 0)
let layer = reversed ? index : max(maxLayer - index, 0)
let skew = Self.depthSkewTransform(
    layer: layer,
    attitude: attitude,
    maxLayer: maxLayer,
    reverseDepthOrder: reverseDepthOrder,
    reverseMotionDirection: reverseMotionDirection,
    perspectiveAmount: perspectiveAmount,
    skewAmount: skewAmount
)
let transformedPath = path.applying(Self.centeredSkewTransform(bounds: path.boundingRect, skew: skew))
```

Then stroke `transformedPath` instead of `paths[index]`.

Keep the existing `.offset(Self.offset(...))` call after the stroke so translation behavior remains unchanged.

- [ ] **Step 3: Pass gated tuning from `CardBackdrop`**

Update the `GuillocheBlendLayer(...)` call:

```swift
perspectiveAmount: elementDepthTuning.perspectiveAmount,
skewAmount: elementDepthTuning.isSkewEnabled ? elementDepthTuning.skewAmount : 0,
reveal: reveal
```

- [ ] **Step 4: Run Visuals tests**

Run:

```bash
cd /Users/adam/Projects/cc/Packages
swift test --filter VisualsTests
```

Expected: tests compile and pass. Snapshot tests may be skipped/host-gated depending on platform; do not re-record snapshots in this task.

## Task 6: Add Developer Toggle And Slider

**Files:**
- Modify: `Packages/Sources/FeatureSettings/DeveloperSettingsPanel.swift`

- [ ] **Step 1: Add toggle and slider after “Depth perspective amount”**

In `elementDepthGroup`, add:

```swift
SettingsDivider()
ToggleRow(
    label: "Enable depth skew",
    isOn: $elementDepthTuning.isSkewEnabled
)
```

Then add:

```swift
SettingsDivider()
SliderRow(
    label: "Depth skew amount",
    value: $elementDepthTuning.skewAmount,
    range: CardElementDepthTuning.Defaults.skewAmountMin...CardElementDepthTuning.Defaults.skewAmountMax,
    format: .decimal,
    tick: SliderRow.Tick(value: CardElementDepthTuning.Defaults.skewAmount, label: "0.08")
)
```

- [ ] **Step 2: Run package tests**

Run:

```bash
cd /Users/adam/Projects/cc/Packages
swift test
```

Expected: package tests pass. If unrelated asset-regeneration changes in the existing worktree cause compile failures, capture the exact failing files and do not modify generated assets as part of this skew task.

## Task 7: Visual Evaluation

**Files:**
- No source edits unless the skew feels too strong or too weak after inspection.

- [ ] **Step 1: Build the app for simulator**

Run:

```bash
cd /Users/adam/Projects/cc
xcodebuild build \
    -scheme CasualContacts \
    -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: build succeeds.

- [ ] **Step 2: Inspect the card visually**

Launch the app on iPhone 17 simulator and inspect a card with guilloche visible. Use Developer Settings to try:

- `Enable depth skew = off`, `Depth skew amount = 0.08`
- `Enable depth skew = on`, `Depth skew amount = 0.00`
- `Enable depth skew = on`, `Depth skew amount = 0.08`
- `Enable depth skew = on`, `Depth skew amount = 0.12`

Acceptance criteria:

- With `Enable depth skew = off`, behavior matches the current translation-only stack.
- With `Enable depth skew = on` and `Depth skew amount = 0.00`, behavior also matches the current translation-only stack.
- With `Enable depth skew = on` and `Depth skew amount = 0.08`, foreground paths shear subtly while retaining the existing x/y parallax.
- The stack should not look like it is melting, stretching text, or sliding off its frame.
- The effect should remain subtle enough that snapshot churn is expected but not visually chaotic.

## Task 8: Cleanup And Diff Review

**Files:**
- Do not touch unrelated generated guilloche files or asset directories.

- [ ] **Step 1: Review scoped diff**

Run:

```bash
cd /Users/adam/Projects/cc
git diff -- \
    Packages/Sources/Visuals/Layers/GuillocheBlendLayer.swift \
    Packages/Sources/Visuals/Layers/CardElementDepthTuning.swift \
    Packages/Sources/Visuals/CardBackdrop.swift \
    Packages/Sources/FeatureSettings/DeveloperSettingsPanel.swift \
    Packages/Tests/VisualsTests/GuillocheBlendLayerTests.swift \
    Packages/Tests/VisualsTests/CardElementDepthTuningTests.swift
```

Expected: only skew-related changes in those files.

- [ ] **Step 2: Report verification evidence**

Report:

- The exact `swift test` command that passed or failed.
- The exact `xcodebuild build` command that passed or failed.
- Any unrelated compile failures caused by the existing dirty asset worktree.
- The chosen default skew value after visual inspection.

Do not commit unless explicitly asked.
