# Plan 5 — HologramText refactor (PDF §5 Title/Name) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the HologramText refactor so the title/name stack on the empty-state "add the first person" button *and* on populated card rows matches `docs/CC Design Specifications.pdf §5 Holograms & Photo Color Models › Title/Name`: two stacked hologram textures (bottom `.lighten`, top `.luminosity`) that transfuse with the gyroscope beneath a two-layer black text mask. Translation + rotation are already wired; this plan regenerates snapshot baselines, adds regression tests for the new view, and closes the loop with an on-device visual QA pass.

**Why now:** Commit `4821d2b` ("refactor(visuals): merge HologramPill into animated HologramText per PDF §5") landed the architectural work. It compiles and host-side tests pass, but the iOS snapshot baselines for `CardSnapshotTests` were captured against the *old* static 56% white fill + single `.luminosity` stack — they're now stale. Until they're regenerated and reviewed, a future unrelated change could silently re-break the title without the suite catching it. There are also no smoke tests exercising the new `HologramText` API directly (attitude plumbing, accessibility-hidden decoration), so regressions there would only surface through the card snapshots indirectly.

**Architecture (as committed in `4821d2b`):** `HologramText` is now a single generic view (`HologramText<Backdrop: View>`) that owns the entire pill stack — previously split across `HologramPill` (backdrop blur + white fill + luminosity texture) and `HologramText` (two black text layers). The merged component layers bottom → top:

1. Blurred duplicate of the scene backdrop (Figma `BACKGROUND_BLUR`, 54.365pt radius)
2. Hologram texture, `.lighten` blend @ 56% — translates `(roll × 12pt, pitch × 8pt)` with `DeviceAttitude`
3. Hologram texture, `.luminosity` blend @ 35% — rotates `roll × 6°` with `DeviceAttitude`
4. Text, black fill, `.overlay` blend
5. Text, 20% black fill, normal blend

Both hologram textures are scaled to 1.3× the pill frame (overscan) so translation and rotation never reveal the underlying stack at full tilt. Translation / rotation / overscan constants are exposed as tuneable static properties on `HologramText` so visual calibration is a one-line change. `attitude` is threaded from `CardView` → `CardTextLayer` → `HologramText` for populated rows, and from `RecordsListScene` → `EmptyStateView` → `HologramText` for the empty state.

**Tech stack:** SwiftUI (`Image(name:bundle:)`, blend modes, `rotationEffect`, `offset`), swift-snapshot-testing (already wired), Swift Testing (`@Test` / `@Suite`), `@testable import Visuals`, `@MainActor` on suites that touch `.body`. Host-side tests run via `swift test`; iOS-gated snapshot tests run via `xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 17'`.

**Prereq:** Plan 4 (bitmap gradients) merged to `main`. Commit `4821d2b` is the current main tip; this plan branches off `main` into `plan/5-hologram-text-refactor`.

---

## File Structure

**New files:**

```
Packages/Tests/VisualsTests/
├── HologramTextSnapshotTests.swift                 ← NEW: attitude-zero vs tilted baselines
```

**Modified files:**

- `Packages/Tests/VisualsTests/HolographicViewsTests.swift` — extend with `HologramText` instantiation + accessibility smoke tests.
- `Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/` — regenerate all PNGs that render the populated-card title stack (name rendered inside the hologram).
- `Packages/Tests/VisualsTests/__Snapshots__/DynamicTypeSnapshotTests/` — regenerate the XXXL card baseline (hologram title stack is visible there too).
- `docs/DESIGN.md` — add a short "HologramText (PDF §5)" subsection under Components with the final layer stack + tuneable constants so the Figma directive "tokens over raw values" has somewhere to point.

**Unchanged (verify no breakage):**
- `Packages/Sources/Visuals/Holographic/HologramText.swift` — reference only; the refactor is already committed.
- `Packages/Sources/Visuals/Holographic/HologramTexture.swift` — the `Neon_3` asset is already the default.
- `Packages/Sources/Visuals/CardView.swift`, `Packages/Sources/FeatureList/EmptyStateView.swift`, `Packages/Sources/FeatureList/RecordsListScene.swift` — attitude threading was committed in `4821d2b`; don't touch again.

---

## Task 1: Branch + sanity build

**Files:**
- None (branch + build only)

- [ ] **Step 1: Create branch**

```bash
cd /Users/adam/Projects/cc
git checkout -b plan/5-hologram-text-refactor
```

Expected: `Switched to a new branch 'plan/5-hologram-text-refactor'`.

- [ ] **Step 2: Verify host-side build still clean**

```bash
cd /Users/adam/Projects/cc/Packages
swift build 2>&1 | tail -5
```

Expected: `Build complete! (<time>s)` — no warnings, no errors. If it fails, stop and report; the refactor in `4821d2b` should build cleanly on a fresh branch.

- [ ] **Step 3: Run host-side test suite to confirm green baseline**

```bash
cd /Users/adam/Projects/cc/Packages
swift test 2>&1 | tail -10
```

Expected: `Test run with 151 tests in 44 suites passed`. Snapshot tests (iOS-gated) are skipped in this run; they run in Task 3.

---

## Task 2: HologramText smoke + accessibility tests (TDD)

**Files:**
- Modify: `Packages/Tests/VisualsTests/HolographicViewsTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `HolographicViewsTests.swift` before the closing `}`:

```swift
    @Test @MainActor func hologramTextInstantiatesAtZeroAttitude() {
        _ = HologramText(
            "jane",
            font: .system(size: 33),
            attitude: .zero,
            backdropSize: CGSize(width: 335, height: 211),
            coordinateSpaceName: "CardScene",
            backdrop: { Color.clear }
        ).body
    }

    @Test @MainActor func hologramTextInstantiatesAtFullTilt() {
        _ = HologramText(
            "jane",
            font: .system(size: 33),
            attitude: DeviceAttitude(pitch: 1.0, roll: 1.0),
            backdropSize: CGSize(width: 335, height: 211),
            coordinateSpaceName: "CardScene",
            backdrop: { Color.clear }
        ).body
    }

    @Test func hologramTextTuningConstantsMatchSpec() {
        // Locks the tuning surface so a silent edit to the defaults shows up
        // as a test diff the reviewer must explain. Values are calibrated
        // against the PDF §5 Title/Name sample on iPhone 11 Pro (375pt).
        #expect(HologramText<Color>.translationScaleX == 12)
        #expect(HologramText<Color>.translationScaleY == 8)
        #expect(HologramText<Color>.rotationDegrees == 6)
        #expect(HologramText<Color>.textureOverscan == 1.3)
    }
```

- [ ] **Step 2: Run the tests to verify they fail (if at all)**

```bash
cd /Users/adam/Projects/cc/Packages
swift test --filter HolographicViewsTests 2>&1 | tail -10
```

Expected: all three new tests **pass** on first run — they exercise the API shape and tuning surface that `4821d2b` already shipped. If any fail, stop and inspect; the committed `HologramText` type signature must match.

*(This task is test-only. TDD purists would object that the tests can't fail because the code is already in place — but the refactor landed as one commit ahead of the test harness. Adding the tests now gives us regression coverage for future edits to `HologramText`.)*

- [ ] **Step 3: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Tests/VisualsTests/HolographicViewsTests.swift
git commit -m "$(cat <<'EOF'
test(visuals): HologramText smoke + tuning-constants regression

Locks the instantiation surface for HologramText at zero and full-tilt
attitude, plus pins the tuning constants (translation scales, rotation,
overscan) so future edits to the defaults surface as a visible diff.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds.

---

## Task 3: Regenerate stale iOS snapshot baselines

**Files:**
- Delete + regenerate: `Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/*.png`
- Delete + regenerate: `Packages/Tests/VisualsTests/__Snapshots__/DynamicTypeSnapshotTests/*.png`

- [ ] **Step 1: Boot iPhone 17 simulator + confirm destination is available**

```bash
xcrun simctl list devices booted | grep -E '(iPhone 17|Booted)'
```

Expected: `iPhone 17 (...) (Booted)` is listed. If not booted, run `xcrun simctl boot "iPhone 17"` before proceeding.

- [ ] **Step 2: Run the snapshot suites once with existing baselines — confirm they fail (proves the old baselines are stale)**

```bash
cd /Users/adam/Projects/cc/Packages
xcodebuild test \
    -scheme CasualContactsPackages-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:VisualsTests/CardSnapshotTests \
    -only-testing:VisualsTests/DynamicTypeSnapshotTests 2>&1 | tail -40
```

Expected: at least one test fails with `assertSnapshot` reporting a non-zero pixel delta. If everything passes, stop and investigate — the hologram stack visually changed (flat 56% white → `.lighten`-blended neon3 texture) so baselines *must* differ at `attitude: .zero`. A pass here means the refactor didn't actually take effect in the built simulator app.

- [ ] **Step 3: Delete stale PNGs**

```bash
cd /Users/adam/Projects/cc
rm Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/*.png
rm Packages/Tests/VisualsTests/__Snapshots__/DynamicTypeSnapshotTests/*.png
```

Expected: no errors. Git will see these as deletions; they'll be regenerated in the next step.

- [ ] **Step 4: Re-run the snapshot suites to record fresh baselines**

```bash
cd /Users/adam/Projects/cc/Packages
xcodebuild test \
    -scheme CasualContactsPackages-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:VisualsTests/CardSnapshotTests \
    -only-testing:VisualsTests/DynamicTypeSnapshotTests 2>&1 | tail -40
```

Expected: all tests **fail** on this first pass with `assertSnapshot` reporting "No reference image found" / "recorded new reference" and writing PNGs into `__Snapshots__/`. This is the recording pass for swift-snapshot-testing when baselines are missing.

- [ ] **Step 5: Re-run a third time to confirm the new baselines are stable**

```bash
cd /Users/adam/Projects/cc/Packages
xcodebuild test \
    -scheme CasualContactsPackages-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:VisualsTests/CardSnapshotTests \
    -only-testing:VisualsTests/DynamicTypeSnapshotTests 2>&1 | tail -15
```

Expected: all tests **pass**. If any fail with a pixel delta, the output is non-deterministic (likely a font-rendering or gradient bundle load race) — stop and investigate before committing.

- [ ] **Step 6: Eyeball the regenerated baselines**

Open each regenerated PNG in Preview / Finder quick-look:

```bash
open Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/
open Packages/Tests/VisualsTests/__Snapshots__/DynamicTypeSnapshotTests/
```

Checklist for each card baseline:
- Title pill still clips to the name's bounding rect + 6pt horizontal padding.
- Name reads as **chromatic** (tinted by the underlying neon3 texture showing through the `.lighten` layer), not flat grayscale black — this is the *intended* visual change from the refactor.
- No hard edges where the two oversized hologram textures end (overscan should hide seams even at the attitude-zero snapshot's zero offset).
- Blurred backdrop still visibly different from the raw gradient (i.e., the `.blur(radius: 54.365)` didn't silently get lost).

If any baseline looks wrong, stop and adjust `HologramText` before committing — a bad baseline becomes a bad regression target.

- [ ] **Step 7: Commit the regenerated baselines**

```bash
cd /Users/adam/Projects/cc
git add Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/ \
        Packages/Tests/VisualsTests/__Snapshots__/DynamicTypeSnapshotTests/
git commit -m "$(cat <<'EOF'
test(visuals): regenerate card snapshot baselines for HologramText refactor

The merged HologramText stack (two hologram textures with .lighten +
.luminosity blends replacing the flat 56% white + single .luminosity)
produces a visibly chromatic title at rest (attitude: .zero) on every
card baseline. Regenerate against the committed refactor so the suite
tracks the new intent.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds.

---

## Task 4: Dedicated HologramText snapshot suite (attitude-zero vs tilted)

**Files:**
- Create: `Packages/Tests/VisualsTests/HologramTextSnapshotTests.swift`
- Create: `Packages/Tests/VisualsTests/__Snapshots__/HologramTextSnapshotTests/` (auto-created on first run)

**Why a dedicated suite:** the existing `CardSnapshotTests` only exercise `attitude: .zero`. Any regression to the motion wiring (e.g., someone re-orders `.offset` vs `.blendMode` and breaks the translation, or swaps `.rotationEffect` for a no-op) would render identically at rest but diverge at tilt. A small snapshot suite at `attitude: .zero` *and* `attitude: DeviceAttitude(pitch: 0.8, roll: 0.8)` locks the tilted state.

- [ ] **Step 1: Write the failing test file**

Create `Packages/Tests/VisualsTests/HologramTextSnapshotTests.swift`:

```swift
#if canImport(UIKit)
import Testing
import SwiftUI
import UIKit
import SnapshotTesting
import CoreModels
import DesignSystem
@testable import Visuals

@Suite @MainActor struct HologramTextSnapshotTests {

    private static let pillSize = CGSize(width: 200, height: 56)
    private static let sceneSize = CGSize(width: 335, height: 211)

    private func hosted(_ attitude: DeviceAttitude) -> UIHostingController<some View> {
        let view = ZStack {
            CCDesign.Gradients.view(for: .sunset)
                .frame(width: Self.sceneSize.width, height: Self.sceneSize.height)

            HologramText(
                "bernard",
                font: CCDesign.Typography.title,
                attitude: attitude,
                backdropSize: Self.sceneSize,
                coordinateSpaceName: "HologramTextSnapshot",
                backdrop: {
                    CCDesign.Gradients.view(for: .sunset)
                        .frame(width: Self.sceneSize.width, height: Self.sceneSize.height)
                }
            )
        }
        .coordinateSpace(.named("HologramTextSnapshot"))
        .frame(width: Self.sceneSize.width, height: Self.sceneSize.height)

        return UIHostingController(rootView: view)
    }

    @Test func atRest_attitudeZero() {
        assertSnapshot(
            of: hosted(.zero),
            as: .image(size: Self.sceneSize)
        )
    }

    @Test func atTilt_pitchAndRollPositive() {
        assertSnapshot(
            of: hosted(DeviceAttitude(pitch: 0.8, roll: 0.8)),
            as: .image(size: Self.sceneSize)
        )
    }

    @Test func atTilt_pitchAndRollNegative() {
        assertSnapshot(
            of: hosted(DeviceAttitude(pitch: -0.8, roll: -0.8)),
            as: .image(size: Self.sceneSize)
        )
    }
}
#endif
```

- [ ] **Step 2: Run to record initial baselines**

```bash
cd /Users/adam/Projects/cc/Packages
xcodebuild test \
    -scheme CasualContactsPackages-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:VisualsTests/HologramTextSnapshotTests 2>&1 | tail -20
```

Expected: three tests **fail** on the first pass with "No reference image found"; PNGs are written to `Packages/Tests/VisualsTests/__Snapshots__/HologramTextSnapshotTests/`.

- [ ] **Step 3: Re-run to confirm stability**

```bash
cd /Users/adam/Projects/cc/Packages
xcodebuild test \
    -scheme CasualContactsPackages-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:VisualsTests/HologramTextSnapshotTests 2>&1 | tail -15
```

Expected: all three tests **pass**.

- [ ] **Step 4: Eyeball the three baselines and confirm they differ**

```bash
open Packages/Tests/VisualsTests/__Snapshots__/HologramTextSnapshotTests/
```

Checklist:
- `atRest_attitudeZero.png` — hologram textures aligned, no translation offset, no rotation.
- `atTilt_pitchAndRollPositive.png` — visibly different from `atRest` (bottom texture shifted down-right by ~9.6pt × ~6.4pt, top texture rotated +4.8°).
- `atTilt_pitchAndRollNegative.png` — mirrored: shifted up-left, rotated −4.8°.

If any two baselines are pixel-identical, the motion wiring is broken — stop and fix `HologramText` before committing.

- [ ] **Step 5: Commit the new suite + baselines**

```bash
cd /Users/adam/Projects/cc
git add Packages/Tests/VisualsTests/HologramTextSnapshotTests.swift \
        Packages/Tests/VisualsTests/__Snapshots__/HologramTextSnapshotTests/
git commit -m "$(cat <<'EOF'
test(visuals): HologramTextSnapshotTests locks tilted motion state

CardSnapshotTests only exercises attitude: .zero, so any regression to
the translate/rotate wiring would render identically at rest. New
suite snapshots rest + ±0.8 tilt so the motion surface is pinned.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds.

---

## Task 5: On-device / simulator visual QA

**Files:**
- None (QA only, no code changes)

**Why manual:** snapshot tests pin the stack but they don't verify the animation *reads* correctly when the device physically tilts. This task is the "does it actually feel holographic?" check.

- [ ] **Step 1: Build + install on iPhone 17 simulator**

```bash
cd /Users/adam/Projects/cc/CasualContacts
xcodebuild build \
    -scheme CasualContacts \
    -destination 'platform=iOS Simulator,name=iPhone 17' -quiet 2>&1 | tail -5

# Derive the DerivedData app-bundle path dynamically (hash varies per
# machine / project path — don't hardcode).
APP_PATH="$(xcodebuild -showBuildSettings \
    -scheme CasualContacts \
    -destination 'platform=iOS Simulator,name=iPhone 17' 2>/dev/null \
    | awk -F' = ' '/CONFIGURATION_BUILD_DIR/ {print $2; exit}')/CasualContacts.app"

xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install "iPhone 17" "$APP_PATH"
xcrun simctl launch "iPhone 17" com.stacksdubeurre.CasualContacts
```

Expected: `Build complete!` then the app launches on the simulator.

- [ ] **Step 2: Visual QA — empty state, both appearance modes**

Uninstall any seed data (fresh install) so the empty state is visible. For each appearance:

```bash
xcrun simctl ui "iPhone 17" appearance light
# Simulator → Device → Rotate / shake / use Features → Toggle In-Call Status Bar to provoke gyro motion
xcrun simctl io "iPhone 17" screenshot /tmp/empty-light.png

xcrun simctl ui "iPhone 17" appearance dark
xcrun simctl io "iPhone 17" screenshot /tmp/empty-dark.png
```

Checklist for each screenshot:
- "add the first person" title is readable and chromatic (not flat black).
- Pill edges are soft and the frosted blur is visible (the sunset gradient behind the pill is discernibly blurred inside the pill vs sharp outside it).
- Chrome (sort, ellipsis) colors still invert per mode — unchanged by this plan.

*(Simulator gyro is zero unless you use Features → Device → Shake or move the window; at attitude zero both tilt-driven layers sit at their rest offsets, so the tilt reading is deferred to Step 4 on physical hardware.)*

- [ ] **Step 3: Visual QA — populated state, both appearance modes**

Add a seed record (use the `+` FAB, name it "Adam"), then screenshot both modes:

```bash
xcrun simctl ui "iPhone 17" appearance light && sleep 1
xcrun simctl io "iPhone 17" screenshot /tmp/populated-light.png

xcrun simctl ui "iPhone 17" appearance dark && sleep 1
xcrun simctl io "iPhone 17" screenshot /tmp/populated-dark.png
```

Checklist:
- Card row name reads chromatic inside the pill (same intent as the empty-state title).
- List-row background chrome (D3 dark / L2 light) is unaffected.
- No visible seams where the overscanned hologram textures end — overscan should hide them.

- [ ] **Step 4 (optional but strongly recommended): physical device motion test**

Deploy to an iPhone via Xcode Run (the `.xcodeproj` has a valid `DEVELOPMENT_TEAM` from commit `4fd92fb`). Hold the device at neutral, then tilt left/right/forward/back:

- Tilt causes the pill's internal color to visibly shift (chromatic transfusion).
- Motion is subtle, not jittery — if it reads as jitter, translation/rotation scales are too high; dial down via `HologramText.translationScaleX` / `translationScaleY` / `rotationDegrees`.
- Reduce Motion in Settings → Accessibility should freeze the hologram at the rest state (via the existing `ReducedMotionAdapter` wiring — no change in this plan).
- Reduce Transparency should *not* affect the hologram layers (they live inside a `.background` modifier — verify this is not a regression).

- [ ] **Step 5: If tuning is needed, commit the adjustments**

If the QA pass surfaces values that need dialing in (translation too strong, rotation too subtle, etc.), edit the static constants at the top of `Packages/Sources/Visuals/Holographic/HologramText.swift`:

```swift
public static var translationScaleX: CGFloat { 12 }   // tune here
public static var translationScaleY: CGFloat { 8 }    // tune here
public static var rotationDegrees: Double { 6 }       // tune here
public static var textureOverscan: CGFloat { 1.3 }    // raise if overscan seams appear at tuned values
```

Then re-run Task 3 and Task 4 to regenerate the now-stale baselines, and commit with a message like `tune(visuals): HologramText translation/rotation defaults`.

- [ ] **Step 6: Write up the QA result**

Append a short note to this plan doc under a new `## QA Log` section (keep in-repo as an audit trail):

```markdown
## QA Log

- **2026-04-18 (Adam):** Simulator QA passed in both appearance modes, empty + populated. Physical-device motion test — TODO (requires iPhone). Tuning defaults kept: 12/8/6/1.3.
```

(Replace values if tuning changed.)

---

## Task 6: Document the final stack in DESIGN.md

**Files:**
- Modify: `docs/DESIGN.md`

- [ ] **Step 1: Add a HologramText subsection**

Find the `## Components` section in `docs/DESIGN.md` (around line 146). After the components table, before the next `##` header, insert:

```markdown
### HologramText (title/name stack per PDF §5)

The animated title element on every card and the empty-state CTA. Merged
component that owns both the frosted pill chrome and the two-layer text
mask. Generic over a backdrop view so it can clone + blur the scene
behind it.

Layer stack (bottom → top), clipped to the text's bounding rect + 6pt
horizontal padding:

1. Blurred duplicate of the caller-supplied backdrop (`BACKGROUND_BLUR`, radius 54.365pt).
2. Hologram texture (`Neon_3` by default), `.lighten` blend @ 56% — translates `(roll × 12pt, pitch × 8pt)` with `DeviceAttitude`.
3. Same hologram texture, `.luminosity` blend @ 35% — rotates `roll × 6°` with `DeviceAttitude`.
4. `Text(...)` with black fill, `.overlay` blend.
5. `Text(...)` with 20% black fill, normal blend.

Both hologram textures are scaled to 1.3× the pill frame so translation
and rotation never reveal the underlying stack at full tilt.

Tuning constants live as `public static var` properties on
`HologramText` (`translationScaleX`, `translationScaleY`, `rotationDegrees`,
`textureOverscan`) — edit those rather than inlining magic numbers at
call sites.

Figma reference: title pill variants on `D_Collection_View` (`277:12836`)
and `L_Collection_View` (`3:215`); empty-state CTA on `D_Collection_View_Empty`
(`335:13907`) and `L_Collection_View_Empty` (`335:15455`). Designer's
notes on the two-fill blend in PDF §5 "Holograms & Photo color models"
› "Title/Name".
```

- [ ] **Step 2: Sanity-check the edit**

```bash
cd /Users/adam/Projects/cc
git --no-pager diff docs/DESIGN.md | head -60
```

Expected: only the new subsection is added; no unintended diffs elsewhere.

- [ ] **Step 3: Commit**

```bash
cd /Users/adam/Projects/cc
git add docs/DESIGN.md
git commit -m "$(cat <<'EOF'
docs(design): document HologramText layer stack + tuning surface

Cross-references PDF §5 Title/Name and the Figma nodes for populated +
empty card variants so future implementers can find the source of
truth for the hologram without re-deriving it from code.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds.

---

## Task 7 (optional — defer to a follow-up plan if scope grows)

PDF §5 also specifies a **Location** hologram (blurred bottom layer that translates on x/y with attitude) and a **Zodiac sign** hologram (translates on x/y). The Zodiac is already implemented via `HolographicZodiac`; the Location is currently rendered as a plain `Text(.white)` in `CardTextLayer` (`CardView.swift:133-139`) with no hologram treatment.

This plan scoped to the Title/Name stack only. If the Location follow-up is in scope, open a Plan 5.1 that:
1. Adds `HologramLocation` (or extends `HologramText` with a blur-enabled variant — decide after brainstorming).
2. Uses attitude-driven `(x, y)` translation (no rotation per spec).
3. Applies blur only to the bottom duplicate layer.
4. Regenerates card snapshots.

Do **not** bolt this onto Plan 5 — the snapshot-regeneration churn doubles and the brainstorming has to happen first.

---

## Merge checklist

After Tasks 1–6 are green:

```bash
cd /Users/adam/Projects/cc
swift test 2>&1 | tail -5                                      # host-side: 151 → 154 tests passing
xcodebuild test \
  -scheme CasualContactsPackages-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:VisualsTests 2>&1 | tail -10                   # iOS-gated visuals suite all green

git checkout main
git merge --ff-only plan/5-hologram-text-refactor
```

Expected: fast-forward merge succeeds (no divergence from main). Delete the branch at the user's discretion.
