# Plan 5 — Cards UI Figma Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the list-row card (Figma `Cards/Full`, node `6:16`) — and by extension the medium + large variants that share `CardTextLayer` — into strict parity with the Figma design. Audit surfaced that the initial implementation was built without full Figma reference: density was wrong, corner radius was wrong, description rendered as a single wrapped `Text` instead of one-pill-per-line, location/date/zodiac-label/moon-label chrome was absent, and the `B/Background` silhouette + right-edge hairlines were never added.

**Why now:** Per CLAUDE.md design-fidelity directive #1 ("Figma is canonical — if the code disagrees with Figma, the code is wrong"), the cards need to match before v1 ships. The list row is the app's primary surface; visible drift undermines the design system's internal consistency across Feature{List, Detail, Create} that all use the same `CardView`.

**Architecture:**
- **`DescriptionPills` view (new)** — Renders description as stacked 1pt-stroke pills, one per visual text line (max 2). Uses CoreText (`CTFramesetterCreateFrame` + `CTFrameGetLines`) against the render font to get line fragments matching what SwiftUI would draw. If natural wrapping produces 3+ lines, pill 2 collapses to the remainder with tail-ellipsis truncation. Lives in `Visuals` because it's a card-internal primitive.
- **`CardTextLayer` layout rewrite** — Replace the current `VStack { name, description, Spacer, location }` with an absolute-positioned ZStack matching Figma `Cards/Full`:
  - top-left (`left:5, top:8`): location hologram pill (Cormorant SC Bold 12 uppercase + 12pt location glyph) with backdrop-blur + `rgba(40,60,85,0.1)` fill
  - top-right (`right:8, top:8`): date/time block — IBM Plex Mono Regular 11pt, two lines (e.g. "Aug 25, 2020" / "Sunset, 5:20 pm")
  - middle-left (`bottom:72, left:8`): name hologram pill (already handled by the in-flight HologramText refactor — out of scope here, but `CardTextLayer` must place it at this position rather than `top`)
  - lower-left (`bottom:8, left:9`, spacing 28pt): description pills via `DescriptionPills`
  - right-column (`right:0, vertically centered`): zodiac stars 100×90, with symbol 35×32 at `right:57 bottom:72`, zodiac label (e.g. "Virgo") at `right:8 bottom:82 translate-y-full` IBM Plex Mono 11pt
  - right-bottom (`right:8 bottom:8`): moon label two lines ("Waxing" / "Crescennt") IBM Plex Mono 11pt
  - right-bottom icon (`right:58 bottom:7`): moon phase glyph 34×56 (replacing the current centered 24×24 version)
  - right-edge hairlines: `bottom-62 right-8 w-6 h-0` + rotated sibling
- **Decorative backdrop layers** — `backdrop()` in `CardView.swift` gains a `BBackgroundSilhouette` layer (Figma `B/Background`, node `15:1147`, 356×356 centered at 13% opacity — a letter-shaped contour line composite) beneath the existing rotation layer. Expose through the existing `CardPathProvider` — silhouette paths generate from the `B/Background_*.svg` drop in `design-assets/` via the existing `Tools/SVGToSwift` pipeline (new input directory).
- **Typography token fix** — `CCDesign.Typography.description` and `.descriptionSmall` currently use `Font.custom("CormorantInfant", size: X)` with a note that `.fontWeight(.semibold)` applies on call sites. SwiftUI does not drive variable-axis weights for `CormorantInfant-Variable.ttf` via the custom-font modifier, so every token consumer silently falls back to Regular. Switch to the named PostScript instance `"CormorantInfant-SemiBold"` at the token level (file already shipped in `AppFeature/Resources/Fonts/` via 6471fa8). Follow-on: audit `AboutView`, `DetailEditForm`, `CreateFormFields` for now-stale `.fontWeight(.semibold)` calls on these tokens and delete.
- **Snapshot baselines** — `VisualsTests/CardSnapshotTests` + `DynamicTypeSnapshotTests` baselines must regenerate because card pixels change across every affected test case. The existing `smallCardMiddayNewMoon` baseline was captured at 335×120 (pre-Figma height); re-record at 335×211.

**Tech Stack:** SwiftUI `ZStack` with `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: …)` for absolute anchoring, `CoreText` (`CTFramesetter`, `CTLine`) for line fragmenting, `Font.custom(namedInstance:)` for variable-font weights, swift-snapshot-testing (already wired).

**Prereq:** Plan 4 (`plan/4-bitmap-gradients`, commit `6471fa8`) merged or at a stable tip. Phase 1 (density collapse `.cards` + corner-radius 4pt) already landed there. The in-flight `HologramText` rewrite unifying the name-pill stack (touching `HologramPill.swift` + `HologramText.swift` in a sibling branch) is an upstream dependency for Phase 2 visual verification — the `CardTextLayer` layout tasks assume the new HologramText API but the pill-rendering swap itself does not.

This plan branches off the HologramText-rewrite tip into `plan/5-cards-ui-figma-parity`. Phase 2 work already in flight on `plan/4-cards-text` (commit `1cb8ca8`) gets rebased in.

---

## File Structure

**New files:**

```
/Users/adam/Projects/cc/Packages/Sources/Visuals/
├── DescriptionPills.swift                               ← NEW (already in plan/4-cards-text)
└── Layers/
    └── BBackgroundSilhouetteLayer.swift                 ← NEW (Phase 3)
```

**Modified files:**
- `Packages/Sources/Visuals/CardView.swift` — CardTextLayer layout rewrite (Phase 2), add BBackgroundSilhouette to backdrop (Phase 3)
- `Packages/Sources/DesignSystem/Typography.swift` — swap to `CormorantInfant-SemiBold` named instance (Phase 4)
- `Packages/Sources/FeatureDetail/DetailEditForm.swift` — remove dead `.fontWeight(.semibold)` (Phase 4)
- `Packages/Sources/FeatureCreate/CreateFormFields.swift` — remove dead `.fontWeight(.semibold)` (Phase 4)
- `Packages/Sources/FeatureSettings/SettingsChrome.swift` — revert to token now that token is SemiBold (Phase 4)
- `Packages/Sources/FeatureSettings/AboutView.swift` — remove dead `.fontWeight(.semibold)` (Phase 4)
- `Tools/SVGToSwift/` — extend pipeline for `B/Background_*` silhouette drop (Phase 3)
- `Packages/Tests/VisualsTests/__Snapshots__/` — regenerated baselines (Phase 5)

**Reference assets (already present):**
- `design-assets/Blended_export/SVG/B_Background/` — 72 line segments composing the silhouette (confirmed via `get_design_context` response enumerating `Vector` children at `15:1075`–`15:1146`)
- `docs/CC Design Specifications.pdf §1` — guilloche technique
- `docs/DESIGN.md §1.3` — density rules

---

## Phase 1 — Density collapse + corner radius — ✅ DONE

**Status:** Landed in `6471fa8` on `plan/4-bitmap-gradients`.

- [x] `CardView.swift`: replace `size == .small ? .preview : .cards` with unconditional `.cards`. `.preview` density is reserved for the deferred Recommended Section (v1.1+).
- [x] `SmallCardListItem.swift`: `.clipShape(RoundedRectangle(cornerRadius: 12))` → `cornerRadius: 4` per Figma `rounded-[4px]`.
- [x] Tests pass; no snapshot regen needed at this stage (covered in Phase 5).

---

## Phase 2 — CardTextLayer layout rewrite

**Files:**
- New: `Packages/Sources/Visuals/DescriptionPills.swift`
- Modify: `Packages/Sources/Visuals/CardView.swift`

**Current partial work:** `plan/4-cards-text` (commit `1cb8ca8`) contains `DescriptionPills.swift` and the description-branch swap. On-device verification was blocked by the concurrent HologramText rewrite — the card's name-pill rendering path changes what `CardTextLayer` can position. Merge after HologramText lands.

### 2a — Description pills (DONE on `plan/4-cards-text`, pending merge)

- [x] Create `DescriptionPills` view: `text: String`, `maxPillWidth: CGFloat`. Body returns `VStack(alignment: .leading, spacing: 1) { pill-per-line }`.
- [x] `layoutLines(text:width:)` static helper: CoreText-based line fragmenting against `CormorantInfant-SemiBold` 18pt, kerning `-0.05`. Returns `[LineFragment]` with trimmed substring + NSRange.
- [x] `segments()`: map line count → `[Segment]`. 0 lines = empty, 1 = one full-pill, 2 = two full-pills, 3+ = first pill full + second pill flagged `truncateToWidth` carrying the remainder substring for SwiftUI tail-ellipsis truncation at pill width.
- [x] Pill styling: `Text` with font, tracking, `.foregroundStyle(.white)`, `.lineLimit(1)`, `.fixedSize(horizontal: true, vertical: false)` (or framed to `maxPillWidth - 12` when truncating), `.padding(.horizontal, 6)`, `.overlay(Rectangle().stroke(CCDesign.Colors.L2, lineWidth: 1))`.
- [x] `CardTextLayer`: replace the description `Text(...)` branch with `DescriptionPills(text: record.description, maxPillWidth: max(0, backdropSize.width - 32 - 60))`.

### 2b — Absolute-positioned layout

- [ ] Rewrite `CardTextLayer.body` as a `ZStack` with per-child `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: …)` + `.padding(…)` matching Figma anchors listed in the Architecture section above.
- [ ] Extract a `LocationPill(label:)` view for the top-left location hologram (border-less backdrop-blur + `rgba(40,60,85,0.1)` fill + 12pt location glyph). Wrap location text in uppercase transform at rendering to match Figma `uppercase` class.
- [ ] Extract a `DateTimeBlock(record:)` view for the top-right text — IBM Plex Mono via `Font.custom("IBMPlexMono-Regular", size: 11, relativeTo: .caption)`. Derive date from `record.createdAt`, time-of-day label from `record.metadata.timeOfDay`, clock time from `record.createdAt`.
- [ ] Extract a `MoonLabel(phase:)` view for the right-bottom — two-line IBM Plex Mono 11pt right-aligned.
- [ ] Extract a `ZodiacLabel(sign:)` view for the right-column — IBM Plex Mono 11pt right-aligned.
- [ ] Reposition the moon-phase glyph from `backdrop()`'s `bottomLeading` 24×24 to right-bottom 34×56 per Figma — update `MoonPhaseLayer` call-site, not the layer itself.
- [ ] Right-edge hairlines: two 6pt lines (`Rectangle().fill(.white.opacity(?))`) — a horizontal tick at `bottom:62 right:8` and a rotated sibling at `bottom:34 right:8` (Figma Line 1/Line 2). Opacity from design tokens; if absent, sample from Figma screenshot and note in a comment.

**Ship gate:** Screenshot side-by-side against `get_screenshot` of `6:16` on an iPhone 17 simulator, using a record with long description + location + zodiac + moon + timestamp. No "close enough" — the hairlines, date block, and zodiac label all land at their Figma positions within a few pixels.

---

## Phase 3 — Decorative backdrop layers

**Files:**
- New: `Packages/Sources/Visuals/Layers/BBackgroundSilhouetteLayer.swift`
- Modify: `Packages/Sources/Visuals/CardView.swift` (backdrop composition)
- Modify: `Tools/SVGToSwift/` (extend for new SVG drop) + regenerate under `Packages/Sources/Visuals/Guilloche/Generated/Background/`

### 3a — SVG pipeline extension

- [ ] Drop the 72 `Vector` children of Figma `15:1147` as SVG files into `design-assets/Blended_export/SVG/B_Background/*.svg`. (The `get_design_context` response enumerates the node IDs — export each via `mcp__plugin_figma_figma__get_design_context` with `excludeScreenshot: true` or the per-layer export flow.)
- [ ] Extend `Tools/SVGToSwift/main.swift` to process a `Background/` input directory and emit to `Packages/Sources/Visuals/Guilloche/Generated/Background/`. Reuse the existing path-emission code — the geometry is line segments, identical to rotation/blend.
- [ ] Update `Tools/regenerate-svg.sh` to include the new directory; expect ~72 additional files in the gitignored `Generated/` tree.
- [ ] Extend `CardPathProvider` with `backgroundSilhouettePaths(for: Character) -> [Path]`. `RealCardPathProvider` in `AppFeature` wires it up per-letter when A/B/C/… silhouettes ship; for v1 a single letter's silhouette (per DESIGN.md the record's derived letter) is acceptable.

### 3b — Silhouette layer

- [ ] `BBackgroundSilhouetteLayer(paths:)` — Canvas or stroked Path overlay at fixed 356×356 frame, centered in the card via `.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)`. Opacity 13% per Figma. `.accessibilityHidden(true)`.
- [ ] Layer order in `CardView.backdrop()`: gradient → rotation → `BBackgroundSilhouetteLayer` → blend (photo or guilloche) → zodiac → moon. The silhouette sits *under* the blend letter to create the 3D depth the designer intended.
- [ ] Respect `@Environment(\.accessibilityReduceTransparency)` — collapse opacity to 0 (i.e. skip the layer) when the user has Reduce Transparency on.

**Ship gate:** Visible but subtle contour behind the main letter; never competes with foreground text. Confirmed on both light mode (sunset/dawn gradient) and dark mode (night gradient) cards.

---

## Phase 4 — Variable-font weight token fix

**Files:**
- Modify: `Packages/Sources/DesignSystem/Typography.swift`
- Modify: `Packages/Sources/FeatureSettings/SettingsChrome.swift`, `FeatureSettings/AboutView.swift`, `FeatureDetail/DetailEditForm.swift`, `FeatureCreate/CreateFormFields.swift`

- [ ] `Typography.description`: `Font.custom("CormorantInfant", size: 18)` → `Font.custom("CormorantInfant-SemiBold", size: 18, relativeTo: .body)`. Delete the stale comment about applying `.fontWeight(.semibold)` at call sites.
- [ ] `Typography.descriptionSmall`: same treatment, size 13 `relativeTo: .footnote`.
- [ ] Grep call sites for `.fontWeight(.semibold)` adjacent to these tokens and delete the no-op modifier.
- [ ] `SettingsChrome.swift` line 34 currently hand-rolls `Font.custom("CormorantInfant-SemiBold", size: 18, relativeTo: .body)` because the token was broken. Revert to `CCDesign.Typography.description` now that the token is correct.
- [ ] Confirm `CormorantInfant-SemiBold.ttf` is registered at launch via `FontRegistration` (already shipped in `6471fa8`).

**Ship gate:** `DesignSystemTests` pass; settings + form labels render at visually-heavier SemiBold weight; no regression in non-description typography (`title`, `headline`, `caption1`, `caption2`).

---

## Phase 5 — Regenerate snapshot baselines

**Files:**
- Regenerate: `Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/*.png`
- Regenerate: `Packages/Tests/VisualsTests/__Snapshots__/DynamicTypeSnapshotTests/*.png`

- [ ] Delete the existing `__Snapshots__/` PNGs for affected tests (`smallCard*`, `mediumCard*`, `largeCard*`, dynamic-type variants).
- [ ] Fix the `smallCardMiddayNewMoon` test to render at 335×211 (Figma height) instead of the stale 335×120 the baseline was captured at.
- [ ] Re-record on iPhone 17 simulator: `xcodebuild test -scheme CasualContactsPackages-Package -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:VisualsTests/CardSnapshotTests`.
- [ ] Review each new PNG against the Figma screenshot for the matching variant.
- [ ] Commit baselines in a dedicated snapshot commit so reviewers can inspect without diffing code.

**Ship gate:** All snapshot tests green on iPhone 17 simulator; tree diff shows expected visual changes, no accidental regressions in time-of-day variants.

---

## Out of scope (deferred)

- Photo card variant (`Cards/Full_w_Photo`, node `39:828`) — the `luminosity` blend + 45–75% opacity photo treatment per DESIGN.md §5 is a separate task. `CardView` already supports a `photo:` param; the Phase 2 absolute layout must accommodate the `PhotoLayer` path without breaking.
- Detail edit form's preview card layout — uses `CardView` but may need its own sizing; inherit Phase 2's fixes transparently, verify visually before claiming done.
- `Cards/Recommended` variants (`59:4544`, `72:3075`) — the Recommended Section is v1.1 and has its own density/layout rules.

---

## Execution notes

- Phase 2 already exists as `plan/4-cards-text` (commit `1cb8ca8`). When re-entering, rebase onto the HologramText-rewrite tip before opening Phase 2b.
- Per CLAUDE.md: fetch fresh Figma context with `get_design_context` at the start of each phase — asset URLs expire after 7 days, and the designer may have pushed updates.
- Keep each phase as its own commit so the snapshot regeneration (Phase 5) is reviewable as a single isolated diff.
