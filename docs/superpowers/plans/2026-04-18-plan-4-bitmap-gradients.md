# Plan 4 — Bitmap-backed gradient system Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 7 hand-authored SwiftUI `LinearGradient` approximations in `CCDesign.Gradients` with the designer's canonical PNG bitmaps (`design-assets/Gradients/*.png`), matching `docs/CC Design Specifications.pdf §2` exactly. Update `GradientLayer`'s transfusion stack to consume bitmap sources so the 0%→50%→100% opacity animation behaves as the designer intended — the top layer's color regions shift against the bottom as attitude changes, an effect impossible with a static `LinearGradient`. Fix `docs/DESIGN.md`'s contradictory reduced-motion note.

**Why now:** The current implementation violates design fidelity directive #2 ("do not cut corners to save effort … picking a hex value from memory instead of reading the current Figma token") and the `feedback_match_figma_blend_effects.md` memory. The sunset gradient visible on the empty-state home screen is a gray/mauve 3-stop approximation — the designer's sunset is a painterly blue-violet → pink → purple bitmap. Transfusion also literally cannot work without bitmap sources: a static linear gradient overlaid at varying opacity has no regions that *shift* — it just dims.

**Architecture:**
- **Asset catalog:** new `Gradients.xcassets` under `Packages/Sources/DesignSystem/Resources/`. One imageset per time-of-day (Dawn, Sunrise, Midday, Sunset, Dusk, Night, Midnight), each wrapping the corresponding PNG from `design-assets/Gradients/`. SPM `.process("Resources")` compiles the catalog at build time and exposes `Bundle.module`.
- **`CCDesign.Gradients` API:** remove the seven `static let … = LinearGradient(…)` properties. Replace with `static func view(for timeOfDay: TimeOfDay) -> GradientBackdrop` + seven named convenience views (`static var sunset: GradientBackdrop { … }`, etc.) that return a `GradientBackdrop` value. Source-compatible for single-layer call sites (`EmptyStateView`); `LinearGradient`-typed call sites get a compile error and must migrate.
- **`GradientBackdrop` view:** new `View` in `DesignSystem` that renders `Image(assetName, bundle: .module).resizable().scaledToFill().accessibilityHidden(true)`. Immutable value type; `Equatable` so SwiftUI diffing works cleanly.
- **`GradientLayer` rewrite:** two stacked `GradientBackdrop` views. Bottom opaque. Top opacity = `(attitude.roll + 1) / 2`, so roll ∈ [-1, 1] → opacity ∈ [0, 1]. Roll = 0 → 50% (spec "Default_50%"). Reduce Motion feeds `attitude = .zero` (unchanged) → stable 50%. Reduce Transparency path keeps the bottom layer only (current behaviour, acceptable translucency fallback).
- **`DESIGN.md` clarification:** correct the reduced-motion sentence — current text claims "zeroes the attitude input, which collapses transfusion to a static single-gradient look — matches the PDF's 'default' state (top opacity fixed at 50%)." The two halves contradict (a single-gradient look ≠ two layers at 50%). Actually the code produces the 50/50 blend; the prose is the bug.
- **Tests:**
  - `GradientsTests` rewrites to verify asset-bundle resolution (each enum case loads a non-nil `UIImage` from `Bundle.module`) and `all` returns seven.
  - `VisualsTests/CardSnapshotTests` baselines regenerate for every time-of-day variant because the underlying image changed.
  - New `VisualsTests/GradientLayerTransfusionTests` snapshot the three canonical transfusion states at spec parity: roll = -1 (0%, bottom only), roll = 0 (50%, "Default"), roll = +1 (100%, top only).

**Tech stack:** SwiftUI `Image(name:bundle:)`, SPM `Bundle.module`, `.process("Resources")` catalog compilation, swift-snapshot-testing (already wired).

**Prereq:** Plan 3 + 3.1 merged to `main`. Repo state includes `Packages/Sources/DesignSystem/Gradients.swift` with the 7 `LinearGradient` statics and `Packages/Sources/Visuals/Layers/GradientLayer.swift` consuming them. Tests all pass.

This plan branches off `main` into `plan/4-bitmap-gradients`.

---

## File Structure

**New files:**

```
/Users/adam/Projects/cc/Packages/
├── Sources/DesignSystem/
│   ├── GradientBackdrop.swift                        ← NEW view wrapper
│   └── Resources/
│       └── Gradients.xcassets/                       ← NEW catalog
│           ├── Contents.json
│           ├── Dawn.imageset/
│           │   ├── Contents.json
│           │   └── Dawn.png
│           ├── Sunrise.imageset/
│           │   ├── Contents.json
│           │   └── Sunrise.png
│           ├── Midday.imageset/
│           │   ├── Contents.json
│           │   └── Midday.png
│           ├── Sunset.imageset/
│           │   ├── Contents.json
│           │   └── Sunset.png
│           ├── Dusk.imageset/
│           │   ├── Contents.json
│           │   └── Dusk.png
│           ├── Night.imageset/
│           │   ├── Contents.json
│           │   └── Night.png
│           └── Midnight.imageset/
│               ├── Contents.json
│               └── Midnight.png
└── Tests/VisualsTests/
    └── GradientLayerTransfusionTests.swift           ← NEW snapshot suite
```

**Modified files:**

- `Packages/Sources/DesignSystem/Gradients.swift` — drop `LinearGradient` properties; expose `GradientBackdrop`-returning convenience vars + `view(for:)`.
- `Packages/Sources/DesignSystem/Package.swift` entry for DesignSystem target — add `.process("Resources")` if not already present; confirm.
- `Packages/Sources/Visuals/Layers/GradientLayer.swift` — stack two `GradientBackdrop` views, keep roll→opacity math, drop `LinearGradient` return type from `gradient(for:)`.
- `Packages/Sources/FeatureList/EmptyStateView.swift` — swap `CCDesign.Gradients.sunset` reference to the new view-typed value (one-line change, still owned by another session — coordinate before editing).
- `Packages/Tests/DesignSystemTests/GradientsTests.swift` — rewrite to verify bundle resolution.
- `Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/` — delete and re-record all PNG references touching gradients (regeneration, not code change).
- `docs/DESIGN.md` — correct reduced-motion gradient note in the Gradients section.

**Unchanged (verify no breakage):**
- `Packages/Sources/AppFeature/ReducedMotionAdapter.swift` — already zeroes attitude; works as-is for the new stack since roll = 0 → 50% opacity.
- `Packages/Tests/AppFeatureTests/ReducedMotionAdapterTests.swift` — unchanged, adapter API didn't change.

---

## Task 1: Register `Gradients.xcassets` asset catalog

**Files:**
- Create: `Packages/Sources/DesignSystem/Resources/Gradients.xcassets/Contents.json`
- Create: 7 × `Packages/Sources/DesignSystem/Resources/Gradients.xcassets/{Name}.imageset/{Contents.json + Name.png}`
- Verify: `Packages/Package.swift` DesignSystem target already declares `.process("Resources")` (it must, since DesignSystem ships fonts). If it does not, add it.

Copy the seven PNGs from `design-assets/Gradients/` into the new catalog at 1× slot. No 2×/3× variants — the PNGs are 689×416 bitmaps and will upscale via `.resizable().scaledToFill()`.

- [ ] **Step 1: Write the failing test**

`Packages/Tests/DesignSystemTests/GradientsTests.swift` (rewrite):
```swift
import Testing
import SwiftUI
import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

@Suite struct GradientsTests {

    private static let names = ["Dawn", "Sunrise", "Midday", "Sunset", "Dusk", "Night", "Midnight"]

    #if canImport(UIKit)
    @Test func allSevenBitmapsResolveFromBundle() {
        for name in Self.names {
            let image = UIImage(named: name, in: .designSystemBundle, compatibleWith: nil)
            #expect(image != nil, "\(name) must be resolvable from DesignSystem bundle")
        }
    }
    #endif

    @Test func allContainsSevenBackdrops() {
        #expect(CCDesign.Gradients.all.count == 7)
    }

    @Test func viewForTimeOfDayReturnsAllSevenDistinct() {
        let all: [CCDesign.GradientBackdrop] = [
            CCDesign.Gradients.view(for: .dawn),
            CCDesign.Gradients.view(for: .sunrise),
            CCDesign.Gradients.view(for: .midday),
            CCDesign.Gradients.view(for: .sunset),
            CCDesign.Gradients.view(for: .dusk),
            CCDesign.Gradients.view(for: .night),
            CCDesign.Gradients.view(for: .midnight),
        ]
        let uniqueNames = Set(all.map(\.assetName))
        #expect(uniqueNames.count == 7)
    }
}
```

The `.designSystemBundle` accessor in the test depends on a small helper exposed internally by DesignSystem:
```swift
// In DesignSystem (internal), add to a suitable file (e.g. GradientBackdrop.swift):
internal extension Bundle {
    static var designSystemBundle: Bundle { .module }
}
```
Exposed only via `@testable import` — not part of public API.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/adam/Projects/cc/Packages
swift test --filter DesignSystemTests.GradientsTests
```

All three tests fail: bundle has no images named Dawn/etc. yet; `GradientBackdrop` type doesn't exist; `Gradients.view(for:)` method doesn't exist; `all` still returns `LinearGradient` array.

- [ ] **Step 3: Create the asset catalog directory structure**

```bash
mkdir -p Packages/Sources/DesignSystem/Resources/Gradients.xcassets
cat > Packages/Sources/DesignSystem/Resources/Gradients.xcassets/Contents.json <<'JSON'
{
  "info" : { "version" : 1, "author" : "xcode" }
}
JSON

for NAME in Dawn Sunrise Midday Sunset Dusk Night Midnight; do
  DIR="Packages/Sources/DesignSystem/Resources/Gradients.xcassets/${NAME}.imageset"
  mkdir -p "$DIR"
  cp "design-assets/Gradients/${NAME}.png" "$DIR/${NAME}.png"
  cat > "$DIR/Contents.json" <<JSON
{
  "images" : [
    { "filename" : "${NAME}.png", "idiom" : "universal", "scale" : "1x" },
    { "idiom" : "universal", "scale" : "2x" },
    { "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "version" : 1, "author" : "xcode" }
}
JSON
done
```

Verify with `ls Packages/Sources/DesignSystem/Resources/Gradients.xcassets/Sunset.imageset/` — both `Contents.json` and `Sunset.png` present.

- [ ] **Step 4: Confirm `Package.swift` DesignSystem target compiles the catalog**

Look for `.target(name: "DesignSystem", ...)` in `Packages/Package.swift`. It should include `resources: [.process("Resources")]`. If missing, add it.

```bash
grep -A 6 'name: "DesignSystem"' Packages/Package.swift
```

- [ ] **Step 5: Run tests (Task 2 will write the type — Task 1 just lands the catalog)**

Task 1's test is scaffolding for Task 2. After Task 1, running the test still fails on type errors (`GradientBackdrop` undefined). That's expected — don't mark Task 1 complete until Task 2 is also complete. Keep Task 1's commit focused on "catalog only": `feat(design-system): register Gradients.xcassets with 7 time-of-day PNGs`.

---

## Task 2: Introduce `GradientBackdrop` view + refactor `CCDesign.Gradients`

**Files:**
- Create: `Packages/Sources/DesignSystem/GradientBackdrop.swift`
- Modify: `Packages/Sources/DesignSystem/Gradients.swift`

`GradientBackdrop` renders a named bitmap via `Image(name:bundle:).resizable().scaledToFill()`. It is `View + Equatable + Hashable` with one stored property (`assetName`). Public initializer takes the `TimeOfDay` enum from `CoreModels` *or* the bare asset name (for future decorative gradients not tied to time-of-day).

`CCDesign.Gradients` drops the `LinearGradient` statics. Its replacement surface is:
```swift
public extension CCDesign {
    enum Gradients {
        public static func view(for timeOfDay: TimeOfDay) -> GradientBackdrop { … }

        // Convenience vars for the seven canonical gradients
        public static var dawn:     GradientBackdrop { .init(assetName: "Dawn") }
        public static var sunrise:  GradientBackdrop { .init(assetName: "Sunrise") }
        public static var midday:   GradientBackdrop { .init(assetName: "Midday") }
        public static var sunset:   GradientBackdrop { .init(assetName: "Sunset") }
        public static var dusk:     GradientBackdrop { .init(assetName: "Dusk") }
        public static var night:    GradientBackdrop { .init(assetName: "Night") }
        public static var midnight: GradientBackdrop { .init(assetName: "Midnight") }

        public static var all: [GradientBackdrop] { [dawn, sunrise, midday, sunset, dusk, night, midnight] }
    }
}
```

Because Package.swift already imports `CoreModels` into DesignSystem (for `TimeOfDay`) — verify this. If not, either add the dependency or move the `view(for:)` method into `Visuals` (which does depend on `CoreModels`) and drop it from DesignSystem's public surface.

- [ ] **Step 1: Write the failing test (already written in Task 1)**

Nothing to add here — tests from Task 1 cover this task's surface.

- [ ] **Step 2: Run tests to verify they still fail**

```bash
cd /Users/adam/Projects/cc/Packages
swift test --filter DesignSystemTests.GradientsTests
```

Compile errors now: `GradientBackdrop` not found, `Gradients.view(for:)` missing.

- [ ] **Step 3: Create `GradientBackdrop.swift`**

```swift
import SwiftUI

public extension CCDesign {
    /// Bitmap-backed full-bleed time-of-day gradient. Renders the designer's
    /// PNG from `Gradients.xcassets` via `Image(name:bundle:).resizable().scaledToFill()`.
    /// Per `docs/CC Design Specifications.pdf §2`, gradients are hand-authored
    /// paintings, not procedural ramps — this view guarantees the canonical source.
    struct GradientBackdrop: View, Equatable, Hashable {
        public let assetName: String

        public init(assetName: String) {
            self.assetName = assetName
        }

        public var body: some View {
            Image(assetName, bundle: .module)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        }
    }
}

internal extension Bundle {
    static var designSystemBundle: Bundle { .module }
}
```

- [ ] **Step 4: Rewrite `Gradients.swift`**

Replace the full file contents with the convenience-vars API shown above. Delete all `LinearGradient` static properties.

**Compile break:** `GradientLayer` and `EmptyStateView` and `GradientsTests` no longer compile against the old API. That is intentional — fixed by Tasks 3 and 4. Run `swift build` and note the exact call sites for the next task.

- [ ] **Step 5: Run Task 1's tests**

```bash
swift test --filter DesignSystemTests.GradientsTests
```

All three pass. Commit: `feat(design-system): GradientBackdrop view + bitmap-backed gradients API`.

---

## Task 3: Rewrite `GradientLayer` to stack two `GradientBackdrop` views

**Files:**
- Modify: `Packages/Sources/Visuals/Layers/GradientLayer.swift`
- Modify: `Packages/Tests/VisualsTests/GradientLayerTransfusionTests.swift` (NEW) — see Task 5
- Modify existing tests referencing `GradientLayer.gradient(for:)` — update signatures.

The existing `static func gradient(for:) -> LinearGradient` must become `static func backdrop(for:) -> CCDesign.GradientBackdrop`. The `body` stacks two backdrops.

Transfusion math unchanged: `(attitude.roll + 1) / 2`. Roll = 0 → 50% → "Default_50%" spec state. Roll = -1 → 0% → bottom only. Roll = +1 → 100% → top only.

Reduce Transparency: top layer is removed, bottom stays. The spec doesn't explicitly address accessibility modes for transfusion; collapsing translucency is a reasonable translation of `@Environment(\.accessibilityReduceTransparency)`'s intent.

- [ ] **Step 1: Write the failing test**

`Packages/Tests/VisualsTests/GradientLayerTransfusionTests.swift`:
```swift
import Testing
import SwiftUI
import CoreModels
@testable import Visuals

@Suite @MainActor struct GradientLayerTransfusionTests {

    @Test func transfusionOpacityAtRollZeroIsDefaultFifty() {
        let opacity = GradientLayer.transfusionOpacity(
            for: DeviceAttitude(roll: 0, pitch: 0),
            reduceTransparency: false
        )
        #expect(opacity == 0.5, "Spec Default_50% requires opacity = 0.5 at roll = 0")
    }

    @Test func transfusionOpacityAtRollNegativeOneIsZero() {
        let opacity = GradientLayer.transfusionOpacity(
            for: DeviceAttitude(roll: -1, pitch: 0),
            reduceTransparency: false
        )
        #expect(opacity == 0.0)
    }

    @Test func transfusionOpacityAtRollPositiveOneIsOne() {
        let opacity = GradientLayer.transfusionOpacity(
            for: DeviceAttitude(roll: 1, pitch: 0),
            reduceTransparency: false
        )
        #expect(opacity == 1.0)
    }

    @Test func reduceTransparencyForcesZeroOpacity() {
        let opacity = GradientLayer.transfusionOpacity(
            for: DeviceAttitude(roll: 0, pitch: 0),
            reduceTransparency: true
        )
        #expect(opacity == 0.0, "Reduce Transparency collapses to bottom layer only")
    }

    @Test func backdropResolvesToDesignSystem() {
        let backdrop = GradientLayer.backdrop(for: .sunset)
        #expect(backdrop.assetName == "Sunset")
    }
}
```

These are pure-math + type-identity tests — no snapshot infrastructure needed yet.

- [ ] **Step 2: Run tests to verify they fail**

Compile errors on `GradientLayer.backdrop(for:)` (doesn't exist) and possibly on the old `LinearGradient` signature still in the file.

- [ ] **Step 3: Rewrite `GradientLayer.swift`**

```swift
import SwiftUI
import CoreModels
import DesignSystem

public struct GradientLayer: View {

    public let timeOfDay: TimeOfDay
    public let attitude: DeviceAttitude

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(timeOfDay: TimeOfDay, attitude: DeviceAttitude) {
        self.timeOfDay = timeOfDay
        self.attitude = attitude
    }

    public var body: some View {
        ZStack {
            Self.backdrop(for: timeOfDay)
            if !reduceTransparency {
                Self.backdrop(for: timeOfDay)
                    .opacity(Self.transfusionOpacity(for: attitude, reduceTransparency: false))
            }
        }
        .accessibilityHidden(true)
    }

    static func backdrop(for timeOfDay: TimeOfDay) -> CCDesign.GradientBackdrop {
        switch timeOfDay {
        case .dawn:     return CCDesign.Gradients.dawn
        case .sunrise:  return CCDesign.Gradients.sunrise
        case .midday:   return CCDesign.Gradients.midday
        case .sunset:   return CCDesign.Gradients.sunset
        case .dusk:     return CCDesign.Gradients.dusk
        case .night:    return CCDesign.Gradients.night
        case .midnight: return CCDesign.Gradients.midnight
        }
    }

    /// Spec §2 "Transfusion": top-layer opacity tracks `attitude.roll` ∈ [-1, 1] → [0, 1].
    /// At roll = 0 (resting / Reduce Motion) the result is 0.5 — the spec's "Default_50%" state.
    static func transfusionOpacity(for attitude: DeviceAttitude, reduceTransparency: Bool) -> Double {
        reduceTransparency ? 0 : (attitude.roll + 1) / 2
    }

    /// Legacy single-argument variant, retained for existing callers/snapshot tests.
    static func transfusionOpacity(for attitude: DeviceAttitude) -> Double {
        transfusionOpacity(for: attitude, reduceTransparency: false)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter VisualsTests.GradientLayerTransfusionTests
```

All 5 pass. Commit: `feat(visuals): GradientLayer stacks two bitmap backdrops for transfusion`.

---

## Task 4: Migrate `EmptyStateView` call site

**Files:**
- Modify: `Packages/Sources/FeatureList/EmptyStateView.swift`

The existing call site reads `CCDesign.Gradients.sunset`. The type changed from `LinearGradient` to `CCDesign.GradientBackdrop`. Both conform to `View`, so the downstream composition (`ZStack { CCDesign.Gradients.sunset; … }`) continues to compile — no other edit needed.

**Coordination note:** `EmptyStateView.swift` is currently edited on another development branch ("leave as-is — other sessions are working on those changes" per session history). Before touching it, confirm with the session owner that Plan 4 can merge this line-level change, or hold the edit until the other branch lands.

- [ ] **Step 1: Check coordination status**

Read current `EmptyStateView.swift`. If the file still calls `CCDesign.Gradients.sunset` directly (no prior rename), proceed. If it has been restructured (e.g. new `HologramPill`, `GeometryReader`), still proceed — the line should be one-for-one source-compatible.

- [ ] **Step 2: Build**

```bash
cd /Users/adam/Projects/cc/Packages && swift build 2>&1 | tail -30
```

Expect green. Any compile error indicates a call site elsewhere that still expects `LinearGradient`. Search and migrate:

```bash
grep -rn "LinearGradient" Packages/Sources/ --include="*.swift"
```

- [ ] **Step 3: Visual check on simulator**

```bash
cd /Users/adam/Projects/cc && xcodebuild build \
    -scheme CasualContacts \
    -destination 'platform=iOS Simulator,name=iPhone 17'
xcrun simctl install "iPhone 17" \
    /Users/adam/Library/Developer/Xcode/DerivedData/CasualContacts-*/Build/Products/Debug-iphonesimulator/CasualContacts.app
xcrun simctl launch "iPhone 17" com.stacksdubeurre.CasualContacts
```

The empty-state sunset should now render the designer's blue-violet → pink → purple painterly bitmap, not the prior gray/mauve linear ramp. Compare side-by-side against `mcp__plugin_figma_figma__get_screenshot` node `335:13907` before reporting complete.

Commit: `refactor(list): empty-state sunset uses designer bitmap backdrop`.

---

## Task 5: Regenerate Card snapshot baselines

**Files:**
- Delete: all PNGs in `Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/` that include a time-of-day gradient in their render path.
- Regenerate via simulator snapshot run.

Every `CardSnapshotTests` baseline that includes a gradient in the render path (e.g. `mediumCardSunsetFullMoon.1.png`) now fails because the underlying gradient bitmap differs from the prior `LinearGradient` output. This is expected and intentional — the baselines are stale.

- [ ] **Step 1: List affected baselines**

```bash
ls Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/
```

The filename convention encodes time-of-day (e.g. `…Sunset…`, `…Midday…`). Every file with a time-of-day token is affected.

- [ ] **Step 2: Run the snapshot suite and observe failures**

```bash
cd /Users/adam/Projects/cc/Packages
xcodebuild test \
    -scheme CasualContactsPackages-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:VisualsTests/CardSnapshotTests 2>&1 | tail -40
```

Note how many tests fail and which filenames. Sanity-check that only gradient-affected tests fail, not guilloche / zodiac / moon tests (they should match pixel-for-pixel — guilloche is a separate pipeline).

- [ ] **Step 3: Re-record**

```bash
rm Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/*Sunset*
rm Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/*Dawn*
# …etc for each time-of-day token that appears in filenames

xcodebuild test \
    -scheme CasualContactsPackages-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:VisualsTests/CardSnapshotTests
```

First run after deletion records new baselines; second run confirms they pass. Visually inspect a sampling of the regenerated PNGs (open them) and compare against a Figma screenshot of the same card variant + time-of-day. If a regenerated baseline doesn't match Figma, the issue is not snapshot drift — it's a bug in the bitmap loader. Surface and stop.

Commit: `test(visuals): regenerate card snapshot baselines against bitmap gradients`.

---

## Task 6: Fix DESIGN.md reduced-motion gradient note

**Files:**
- Modify: `docs/DESIGN.md`

The current text in the Gradients section says:

> The reduce-motion adapter (`Packages/Sources/AppFeature/ReducedMotionAdapter.swift`) zeroes the attitude input, which collapses transfusion to a static single-gradient look — matches the PDF's "default" state (top opacity fixed at 50%).

This is internally contradictory — a "static single-gradient look" is not the same as "top opacity fixed at 50%" (which renders both layers visibly blended). The code produces the 50/50 blend; the prose is wrong.

- [ ] **Step 1: Replace with accurate description**

```markdown
The reduce-motion adapter (`Packages/Sources/AppFeature/ReducedMotionAdapter.swift`) zeroes the attitude input. With `attitude.roll = 0`, `GradientLayer.transfusionOpacity` returns `0.5` — both layers render stacked at 50% opacity, the spec's "Default_50%" resting state. No animation, both bitmaps still visible — matches the PDF's middle demonstration frame.
```

- [ ] **Step 2: Update the Gradients table note about exported assets**

Add a sentence: "Seven PNGs ship in `Packages/Sources/DesignSystem/Resources/Gradients.xcassets/` as the canonical bitmap source. `CCDesign.Gradients.*` and `GradientLayer` consume them via `Bundle.module`."

Commit: `docs: correct DESIGN.md reduced-motion gradient note + record asset location`.

---

## Task 7: Full-build verification + DESIGN.md token reference

**Files:** none (verification only)

- [ ] **Step 1: Full `swift test` on macOS host**

```bash
cd /Users/adam/Projects/cc/Packages && swift test 2>&1 | tail -10
```

All ~125+ tests pass. No gradient or snapshot regressions.

- [ ] **Step 2: Full iOS simulator test run**

```bash
xcodebuild test \
    -scheme CasualContactsPackages-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
```

Includes `CardSnapshotTests` + `GradientLayerTransfusionTests`.

- [ ] **Step 3: Visual QA on simulator (empty + populated)**

Empty state: sunset backdrop renders as designer's painterly bitmap (blue-violet → pink → purple), not gray/mauve.

If populated data fixtures exist (they may not in v1), toggle a card to each time-of-day and confirm each bitmap renders correctly. Otherwise defer to Plan 3.1 sample-data or manual insertion.

Tilt the device (Debug → Device → Rotation) and confirm the transfusion reads correctly — color regions shift, not just a dim-up/dim-down.

- [ ] **Step 4: Reduce Motion + Reduce Transparency QA**

Settings → Accessibility → Motion → Reduce Motion ON: gradient should appear static at 50% blend (both bitmaps stacked, no tilt response).

Settings → Accessibility → Display & Text Size → Reduce Transparency ON: only the bottom bitmap renders, no translucent top layer.

- [ ] **Step 5: Merge fast-forward**

Standard plan-execution workflow. `git checkout main && git merge --ff-only plan/4-bitmap-gradients && git branch -d plan/4-bitmap-gradients`.

---

## Risks & mitigations

- **Bundle.module resolution flakes in macOS host tests.** DesignSystem has no macOS-specific code, but if `Bundle.module` fails to locate the xcassets, the `namedGradientsExist`-style test fails only on macOS. Mitigation: run asset-resolution tests under `#if canImport(UIKit)` as the test shows; macOS host tests verify API shape only.
- **Asset catalog not compiled into the app bundle.** SPM `.process("Resources")` *must* be on the DesignSystem target. Verify in Task 1 Step 4. Without it, `Image(name:bundle:)` returns a blank view at runtime.
- **Snapshot regeneration may mask real rendering bugs.** Before recording new baselines, visually compare a sample against the Figma screenshot. If the bitmap renders washed-out or stretched, do not record — investigate scaling and `.scaledToFill()` vs `.scaledToFit()` first.
- **Other sessions touching `EmptyStateView`.** Task 4 is a one-line change, but if the other session has not merged, coordinate or rebase before running the simulator verification in Task 4 Step 3.
- **`TimeOfDay` import into DesignSystem.** If DesignSystem doesn't already depend on CoreModels (it ships colors/typography/fonts — probably not), the `view(for timeOfDay:)` method needs to move to Visuals. Confirm in Task 2 Step 3 and refactor if necessary — push the enum-to-asset mapping into `GradientLayer.backdrop(for:)` (which already has it as a switch).

---

## Definition of done

- [ ] `Packages/Sources/DesignSystem/Resources/Gradients.xcassets/` contains 7 imagesets, each with the designer's PNG.
- [ ] `CCDesign.Gradients` public API returns `CCDesign.GradientBackdrop` values; no `LinearGradient` references remain in `Packages/Sources/DesignSystem/` or its direct consumers.
- [ ] `GradientLayer` stacks two `GradientBackdrop` views; `transfusionOpacity(roll: 0) == 0.5`.
- [ ] Empty-state home screen on iPhone 17 simulator renders the designer's sunset bitmap; a reviewer confirms it matches Figma `335:13907` side-by-side.
- [ ] `swift test` + full iOS simulator test run both green.
- [ ] `docs/DESIGN.md` Gradients section accurately describes the bitmap-backed stack + 50% reduced-motion default.
- [ ] Reduce Motion and Reduce Transparency accessibility behaviours verified on simulator.
