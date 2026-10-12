# Casual Contacts

iOS app for quickly recording people you've just met in casual settings — cafés, parties, concerts — where you might only have a first name and a short association. The app auto-captures ambient metadata (time, time-of-day label, moon phase, optional location) and derives a unique visual "card" from that metadata to reinforce memory through mental association.

Use the current source, Git history, and `TODO.md` to check project status. Plans in `docs/superpowers/` are historical context; check their requirements against the current source before you use them.

## Canonical docs

- **Design reference (screen → Figma map + designer techniques):** `docs/DESIGN.md` — Figma layer + node ID for every screen, component, token, gradient, guilloche, hologram, moon phase, zodiac sign, plus the designer's PDF notes inlined per category. Load on-demand when touching visuals. **Design fidelity directives are below** — read them every session.
- **Design spec:** `docs/superpowers/specs/2026-04-17-casual-contacts-design.md` — architecture, data model, screens, visual system, testing strategy, accessibility. Use it for design and architecture context. Current user instructions and repository policies take precedence over historical specifications.
- **Design specifications PDF:** `docs/CC Design Specifications.pdf` — designer-authored, explains guilloche techniques (rotation + blend), holographic blend-mode stacks, photo treatments.
- **Original proposal:** `docs/proposal/Casual_Contacts_App_Proposal.pdf` — 2020-era pitch; functional requirements are still valid, aesthetic direction was superseded by the Figma designs.
- **Figma file:** aesthetic source of truth. Pages + node IDs in `docs/casual-contacts-figma.md`. Check the available Figma connection when you need access; do not assume an account or permission level.
- **Plans:** `docs/superpowers/plans/` — read a relevant plan when it helps with the task. Do not require a new plan for routine changes.

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

## Worktree and Git policy

Keep the root checkout on `main`. Create a separate branch in a linked worktree
under `.worktrees/<branch-name>/`. Use relative paths from that worktree.
Do not link dependencies, credentials, data, or build output to another checkout.

Agents may commit and push task-related branches to GitHub without a separate
permission request. Do not force-push, delete remote branches, publish a release,
or merge into `main` unless the current task authorizes that action. Check the
staged diff for secrets before a commit.

Use `dev/*` branches for development TestFlight builds. A push starts the
`Development TestFlight` Xcode Cloud workflow. It produces an internal-only build
and distributes it only to the `Development` group. Use
`Tools/testflight-dev.sh` to push a clean development branch. See
`docs/development-testflight.md` for setup and verification.

`Tools/release.sh` and `Tools/testflight.sh` create and push tags for the existing
release and core-test workflows. Use them only for an authorized release or
core-test build. Do not use them for development branch builds.

## Common workflows

Run commands from the active checkout. Prefix shell commands with `rtk` as
specified in the local machine instructions.

### Fast checks

For pure Swift changes, run the relevant host tests from `Packages`:

```sh
cd Packages
rtk proxy swift test
```

For CI script changes:

```sh
rtk proxy node --test Tools/ci-post-clone.test.mjs Tools/testflight-dev.test.mjs
```

For iOS-specific tests, select an available simulator and run the smallest
relevant test set. Do not assume a simulator name is available. Read the local
Simulator lifecycle skill before you create, boot, or shut down a simulator.
Use existing coverage. Add tests when they preserve an important behavior.

### Build and run

Prefer available XcodeBuildMCP tools for supported build and simulator actions.
For a physical phone, discover the device with `xcrun devicectl list devices`.
Build the `CasualContacts` scheme from
`CasualContacts/CasualContacts.xcodeproj` for that device. Use a derived-data
path inside the active worktree, then install and launch with `devicectl`.
Do not assume a device identifier, pairing state, or network route.

For simulator builds, select an available simulator, use derived data inside the
active worktree, and install the resulting app. The bundle ID is
`com.stacksdubeurre.CasualContacts`.

Use an available accessibility hierarchy tool to inspect controls and text.
Use screenshots when pixels matter, including Figma comparisons and blend-mode
checks. Do not require one particular simulator plugin or ask for dependency
installation if an available tool can perform the check.

### Regenerate guilloche Swift files

After changes under `Tools/SVGToSwift/` or new SVGs in
`design-assets/Guilloche/App/`, run:

```sh
rtk proxy ./Tools/regenerate-svg.sh
```

This produces files in `Packages/Sources/Visuals/Guilloche/Generated/`.

### Snapshot tests

Committed reference images are in
`Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/`.
Run the relevant snapshot tests for visual changes. Inspect diffs before you
update reference images. Do not delete the references to make a failure pass.

### Motion diagnostics

Debug builds expose Settings → Motion debug. Use it to inspect the CoreMotion
pipeline when the task requires motion diagnostics.

## Task execution

Use the smallest workflow that completes the requested task. Read relevant
project documentation, make the change in the active worktree, run appropriate
checks, and report the result with a verification path. Work sequentially unless
the user requests delegation. Keep release and App Store actions within the
scope the user authorized.

## Patterns that have emerged (follow these)

- **Swift 6 strict concurrency** is on. When a test `@Test` function accesses a view's `.body` or touches `@MainActor` state, annotate the test (or the `@Suite`) with `@MainActor`. Without it Swift Testing's parallel workers trigger UIKit/actor crashes.
- **iOS-only APIs** (`.navigationBarTitleDisplayMode`, `.topBarLeading/.topBarTrailing`, `.presentationDetents`, `.fullScreenCover`) must be wrapped with `#if os(iOS)` because the package supports macOS for host-side testing. Provide minimal macOS fallbacks (usually a plain `Text` or `.primaryAction` placement).
- **CoreMotion is not available on macOS** despite being importable. Gate `CoreMotionService` class with `#if canImport(CoreMotion) && !os(macOS)`. `AttitudeLowPass` (pure math) stays cross-platform.
- **CLAuthorizationStatus.authorizedWhenInUse** is iOS-only; wrap with `#if os(iOS)` on the `case` branches.
- **Assets:** SVG resources consumed by SwiftUI `Image(name:bundle:)` must live in `.xcassets` catalogs, not loose Resources folders. SPM `.process("Resources")` compiles the catalog automatically.
- **Font names:** `CormorantInfant` is a variable-axis font; use `Font.custom("CormorantInfant", size:)` plus `.fontWeight(.semibold)` rather than a named SemiBold variant.
- **UUID hashing for stable derivations:** Swift's `String.hashValue` is process-seeded. For deterministic cross-launch derivations, hash the raw UUID bytes (see `VisualAccoutrements.accoutrements` for the byte-sum pattern).

## Backlog

Use `TODO.md` and current task requirements for the backlog. Historical plans
contain proposed work and past observations; do not treat them as verified
current defects or incomplete tasks. The app already has a UI test target and
Icon Composer artwork.

## Quirks & conventions

- **Source filename typos preserved:** the designer's SVG filenames include `Waxing_Crescennt` and `Waning_Crescennt` (double-n). The `MoonPhase` enum uses correct spelling; `MoonPhaseLayer.assetName(for:)` maps between them.
- **Cyrillic folder name preserved:** `design-assets/Zodiac/Сonstellations/` starts with Cyrillic С, not Latin C. We copy the files into a normalized `Zodiac.xcassets` at build time so the Cyrillic leak doesn't reach the app bundle.

## Local machine configuration

Read `~/.codex/AGENTS.machine.md` when present. Keep local account, credential,
tool installation, and memory paths out of shared repository instructions.
