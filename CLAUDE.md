# Casual Contacts

iOS app for quickly recording people you've just met in casual settings — cafés, parties, concerts — where you might only have a first name and a short association. The app auto-captures ambient metadata (time, time-of-day label, moon phase, optional location) and derives a unique visual "card" from that metadata to reinforce memory through mental association.

**Status (2026-04-18):** Plans 1–3 merged to `main`. Installable v1 running on iPhone 17 simulator, empty state visible. Plan 3.1 tracks remaining polish.

## Canonical docs

- **Design reference (screen → Figma map + designer techniques):** `docs/DESIGN.md` — Figma layer + node ID for every screen, component, token, gradient, guilloche, hologram, moon phase, zodiac sign, plus the designer's PDF notes inlined per category. Load on-demand when touching visuals. **Design fidelity directives are below** — read them every session.
- **Design spec:** `docs/superpowers/specs/2026-04-17-casual-contacts-design.md` — architecture, data model, screens, visual system, testing strategy, accessibility. If anything here conflicts, the spec wins.
- **Design specifications PDF:** `docs/CC Design Specifications.pdf` — designer-authored, explains guilloche techniques (rotation + blend), holographic blend-mode stacks, photo treatments.
- **Original proposal:** `docs/proposal/Casual_Contacts_App_Proposal.pdf` — 2020-era pitch; functional requirements are still valid, aesthetic direction was superseded by the Figma designs.
- **Figma file:** aesthetic source of truth. Pages + node IDs in `docs/casual-contacts-figma.md`. Figma MCP is authenticated for `hello@therealadammork.com`; both Stacks du Beurre and Beonest teams give Expert access.
- **Plans:** `docs/superpowers/plans/` — each plan is a TDD-driven task list. Read the relevant plan before starting a task.

## Design fidelity directives

Figma is the source of truth for every visible screen, component, and asset. These rules apply to **all** UI work. Detailed Figma layer/node map + designer techniques live in `docs/DESIGN.md` — load it on-demand when implementing visuals.

1. **Figma is canonical.** If the code disagrees with Figma, the code is wrong. Update the code. Don't "adapt" Figma to match what's already built.

2. **Do not cut corners to save effort.** Do not ship a visual that differs from Figma because the "close enough" asset was easier. Examples to refuse:
   - Rendering the app-icon composite when Figma specifies only the glyph.
   - Hand-editing an existing SVG instead of fetching the canonical layer.
   - Picking a hex value from memory instead of reading the current Figma token.
   - Copy-pasting a prior screen's layout because it "looks similar" without checking the new Figma node.

3. **Reuse primitives, don't rebuild them.** We maintain a shared UI library (`DesignSystem`, `Visuals`, shared Feature components). If a fundamental primitive — button, text field, card, list row, sheet chrome, typography style — already exists and can be configured to match the Figma spec through reasonable parameters (color, size, padding, variant, typography token), **reuse it and style it.** Creating parallel primitives per screen causes drift and violates the design system. The test is: *can this primitive reach the Figma spec by changing documented style inputs?* If yes, reuse. If no (genuinely new behavior, geometry, or composition), build a new primitive and add it to the shared library so the next screen can reuse it too.

4. **Reuse ≠ skipping Figma.** Even when reusing a component, still fetch the Figma node for the screen you're building. You need it to know which variant/props to set and to verify the final composition.

5. **Fetch fresh every time.** Figma asset URLs expire (7 days). Re-run `get_design_context` for the specific node at the start of each task; don't rely on previously-downloaded renders.

6. **Render the exact layer.** If Figma calls out a specific named layer (e.g. `imgVector` inside a parent frame), export *that* layer, not the parent composite. Confirm via `get_metadata` before rasterizing.

7. **Flexible layout, fixed design.** Reproduce Figma's proportions, hierarchy, spacing, and visual stack faithfully. Layout should breathe across device sizes (relative sizing, safe areas, Dynamic Type) — but the *design* doesn't change across devices.

8. **Tokens over raw values.** When Figma exposes a named variable (e.g. `Dark/D4`), prefer the token name in code/comments over a raw hex so token changes propagate.

9. **Verify visually.** After implementing, screenshot the simulator and compare side-by-side against the Figma screenshot. Do not report "matches Figma" without this check.

10. **Ambiguity is a stop sign.** Missing states (pressed, disabled, error, empty, loading)? Surface the gap and ask. Do not invent.

## Architecture at a glance

```
App Target (CasualContacts/)         ← thin @main shell
      │ imports AppFeature
      ▼
AppFeature                            ← wiring layer, only module that sees concrete services
      │
      ├── Feature{List,Create,Detail,Settings}   ← depend on CoreModels protocols only
      │
      ├── Visuals (CardView + layers)            ← SwiftUI, Canvas, blend modes
      │
      ├── DesignSystem                           ← colors, typography, fonts, gradients
      │
      ├── CoreModels                             ← pure types + protocols, zero framework deps
      │
      ├── Storage (SwiftDataRecordStore, FileSystemPhotoStore)
      │     └── StorageTestSupport (InMemory fakes)
      │
      └── Services (CoreLocationService, CoreMotionService, MoonPhase/TimeOfDay)
            └── ServicesTestSupport (Mock/Static/Fixed fakes)
```

**Rule:** Feature modules only import `CoreModels` protocols, `DesignSystem`, and `Visuals`. They never see SwiftData, CoreLocation, or CoreMotion directly. The compiler enforces this via Swift Package target dependencies.

## Common workflows

### Run tests on macOS host

```bash
cd /Users/adam/Projects/cc/Packages
swift test
```

Expected: ~125 tests pass across ~36 suites. Fast, no simulator needed. Use this for quick feedback while iterating on pure-Swift code.

### Run tests on iOS simulator

```bash
cd /Users/adam/Projects/cc/Packages
xcodebuild test \
    -scheme CasualContactsPackages-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17'
```

Needed for: `CardSnapshotTests` (UIKit-gated), `AppEnvironmentTests.production()` (CoreMotion-gated), anything that exercises actual iOS APIs.

### Build + install the app

```bash
cd /Users/adam/Projects/cc
xcodebuild build \
    -scheme CasualContacts \
    -destination 'platform=iOS Simulator,name=iPhone 17'

xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install "iPhone 17" \
    /Users/adam/Projects/cc/CasualContacts/build/Debug-iphonesimulator/CasualContacts.app
xcrun simctl launch "iPhone 17" com.stacksdubeurre.CasualContacts
```

### Inspect / debug the running app (iOS Simulator MCP)

The `ios-simulator` MCP (joshuayoes/ios-simulator-mcp, configured in `.mcp.json`) is the preferred way to drive, screenshot, and inspect the simulator from within a session. Use it whenever you need to verify a visual change, reproduce a UI bug, or debug a layout issue — don't ask the user to describe what they see if you can look yourself.

Tools most relevant to this project (all namespaced `mcp__ios-simulator__*`):

- **`screenshot` / `ui_view`** — visual check after a build+install. `ui_view` returns an inline compressed image (fast, good for quick checks); `screenshot` writes a file (use when you need to diff against Figma).
- **`ui_describe_all`** — **the go-to tool for debugging layout issues.** Returns the full accessibility hierarchy for the current screen: every element's frame, label, identifier, traits, and nesting. Use this instead of guessing when:
  - Something is "not showing up" — check whether the element is in the tree at all, and if so what its frame is (off-screen? zero-sized? covered?).
  - A tap isn't landing — confirm the actual on-screen bounds before re-running `ui_tap`.
  - A card/row looks wrong — compare reported frames against Figma's expected proportions.
  - VoiceOver labels need auditing for the accessibility pass (Plan 3.1 T10).
- **`ui_describe_point`** — element at specific x,y. Useful when you have a screenshot with a suspicious region and want to know *which* element is there.
- **`ui_tap` / `ui_swipe` / `ui_type`** — drive flows (e.g. empty state → tap + → type name → Save) to reach the screen you need to inspect.
- **`launch_app` / `install_app`** — after a fresh `xcodebuild build`, `install_app` + `launch_app com.stacksdubeurre.CasualContacts` is equivalent to the `simctl` commands above.

Typical debugging loop: build + install → `launch_app` → `ui_describe_all` to understand the current tree → `screenshot` for a visual → adjust SwiftUI → rebuild → re-inspect. This is much faster and more reliable than eyeballing screenshots alone when the issue is a frame/layout bug.

Prerequisites: Facebook IDB (`brew install idb-companion` + `pipx install fb-idb --python python3.11`). If IDB isn't installed, the MCP tools will fail with a connection error — ask the user to install it rather than falling back to guesses.

### Regenerate guilloche Swift files

After any change to `Tools/SVGToSwift/` or a new drop of SVGs in `design-assets/Rotation/` or `design-assets/Blended_export/SVG/`:

```bash
cd /Users/adam/Projects/cc
./Tools/regenerate-svg.sh
```

Produces ~130 Swift files in `Packages/Sources/Visuals/Guilloche/Generated/` (gitignored). Without this, `RealCardPathProvider` fails to compile.

### Run snapshot tests (visual regression)

Reference images live at `Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/`. Committed. Only re-run when visuals intentionally change:

```bash
cd /Users/adam/Projects/cc/Packages
xcodebuild test \
    -scheme CasualContactsPackages-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:VisualsTests/CardSnapshotTests
```

Delete the PNGs first if you want to re-record from scratch.

## Plan execution workflow

We use the `superpowers:subagent-driven-development` skill. One plan per major chunk of work. Branch → execute tasks → review → merge fast-forward to main.

1. Read the plan file from `docs/superpowers/plans/`.
2. `git checkout -b plan/<N>-<short-name>`.
3. Create TaskCreate entries for each task in the plan.
4. Dispatch implementer subagent per task with the task text + scene-setting context. Agents should `Read` the plan file for details; don't inline 500-line task descriptions.
5. After each task: verify tests pass, commit, mark task complete.
6. For mechanical tasks a combined spec+quality review works; for substantive tasks run them separately per the skill.
7. After all tasks: merge fast-forward, delete branch.

Plans 1, 2, and 3 followed this pattern. Each produced 15–20 TDD commits.

## Patterns that have emerged (follow these)

- **Swift 6 strict concurrency** is on. When a test `@Test` function accesses a view's `.body` or touches `@MainActor` state, annotate the test (or the `@Suite`) with `@MainActor`. Without it Swift Testing's parallel workers trigger UIKit/actor crashes.
- **iOS-only APIs** (`.navigationBarTitleDisplayMode`, `.topBarLeading/.topBarTrailing`, `.presentationDetents`, `.fullScreenCover`) must be wrapped with `#if os(iOS)` because the package supports macOS for host-side testing. Provide minimal macOS fallbacks (usually a plain `Text` or `.primaryAction` placement).
- **CoreMotion is not available on macOS** despite being importable. Gate `CoreMotionService` class with `#if canImport(CoreMotion) && !os(macOS)`. `AttitudeLowPass` (pure math) stays cross-platform.
- **CLAuthorizationStatus.authorizedWhenInUse** is iOS-only; wrap with `#if os(iOS)` on the `case` branches.
- **Assets:** SVG resources consumed by SwiftUI `Image(name:bundle:)` must live in `.xcassets` catalogs, not loose Resources folders. SPM `.process("Resources")` compiles the catalog automatically.
- **Font names:** `CormorantInfant` is a variable-axis font; use `Font.custom("CormorantInfant", size:)` plus `.fontWeight(.semibold)` rather than a named SemiBold variant.
- **UUID hashing for stable derivations:** Swift's `String.hashValue` is process-seeded. For deterministic cross-launch derivations, hash the raw UUID bytes (see `VisualAccoutrements.accoutrements` for the byte-sum pattern).

## Outstanding work — Plan 3.1

Polish tasks deferred from Plan 3:

- **T10 — Accessibility pass**
  - Dynamic Type scaling verified at XXXL on all cards
  - Composite VoiceOver labels on every card
  - `.accessibilityHidden(true)` on decorative layers (gradients, guilloche, holograms)

- **T11 — Reduce Motion / Reduce Transparency**
  - `MotionService` publishes `.zero` permanently when `UIAccessibility.isReduceMotionEnabled`
  - Blend-mode stacks collapse to solid fills when `isReduceTransparencyEnabled`
  - Hologram rotations, transfusion opacity shifts, letter-blend parallax all static in reduced-motion mode

- **T13 — XCUITest suite**
  - Target creation may require manual Xcode UI step (File → New → Target → iOS UI Testing Bundle)
  - Cover: first launch → empty state → tap + → enter name → Save → verify row appears

- **T14 — App icon**
  - Export from Figma node `388:13592` at iOS 18 required sizes
  - Populate `CasualContacts/CasualContacts/Assets.xcassets/AppIcon.appiconset/`
  - Verify release-mode `xcodebuild build -configuration Release` succeeds

## Known rough edges worth verifying on simulator

- Fonts may not visually resolve as Cormorant even though `FontRegistration` runs — snapshot pass last verified before `FontRegistration` wiring. Do a visual QA pass on an iOS simulator build.
- CardView layout in small/medium/large sizes may need proportional tweaks — the zodiac layer currently takes a large chunk of the card with no frame constraint in the snapshot that was captured.
- Empty-state placeholder glyph is a rounded rectangle; should eventually use the `A/Polygon` asset from design-assets.

## Deferred to v1.1+ (beyond Plan 3.1)

Per the design spec Section 8. Clean seams exist for each:

- Recommended section (location-proximity retrieval)
- Default + Advanced Sorting screens
- 2-person add flow
- iCloud sync (SwiftData `ModelConfiguration(cloudKitDatabase:)`)
- Advanced Card Stack list layout
- Phone / email fields

## Quirks & conventions

- **Source filename typos preserved:** the designer's SVG filenames include `Waxing_Crescennt` and `Waning_Crescennt` (double-n). The `MoonPhase` enum uses correct spelling; `MoonPhaseLayer.assetName(for:)` maps between them.
- **Cyrillic folder name preserved:** `design-assets/Zodiac/Сonstellations/` starts with Cyrillic С, not Latin C. We copy the files into a normalized `Zodiac.xcassets` at build time so the Cyrillic leak doesn't reach the app bundle.
- **Nobody pushes to GitHub from the agent.** Push is a user-visible action — ask first. Currently `main` is 43 commits ahead of `origin/main` (all local).

## Memory

Auto-memory at `/Users/adam/.claude/projects/-Users-adam-Projects-cc/memory/`. Honored in every session automatically. Current entries:

- `feedback_avoid_political_references.md` — no political figures in examples
- `feedback_structure_for_future_refactor.md` — skip deferred features, but keep boundaries clean for later

Add to `MEMORY.md` when you learn something durable about the user or project that isn't obvious from code.
