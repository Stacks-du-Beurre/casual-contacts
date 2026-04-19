# Create-Flow Redesign — Design Spec

**Date:** 2026-04-19
**Branch:** `contact-create-ui-fixes`
**Figma source:** [`L_Add_new_Name_1P`](https://www.figma.com/design/aYjd42Fr66HRCV0vQcJAtS/Casual-Contacts?node-id=185-8911) (node `185:8911`)
**Related canonical docs:** `docs/DESIGN.md` §"Create — name only", `docs/superpowers/specs/2026-04-17-casual-contacts-design.md`

## 1. Background

The current create flow (`Packages/Sources/FeatureCreate/`) presents a miniature `CardView` preview on top of a plain `TextField`/`TextField` stack inside a `NavigationStack` with system toolbar. That composition does not match the Figma design. The redesign replaces it with a custom screen that visually composites editable fields directly onto the card atmosphere — name and description appear as inline pills floating over the gradient/guilloche backdrop, with an autofilled location/time strip and a full-width SAVE button below.

## 2. Goals

- 1:1 visual parity with Figma node `185:8911` for the empty (pre-fill) state.
- Reuse the card's atmospheric backdrop (gradient + guilloche layers + photo) via a new shared `CardBackdrop` component in `Visuals`.
- Preserve the existing `Record` / `RecordDraft` data model and the `onSave`/`onCancel` callback surface.

## 3. Non-goals / deferred

- **Zodiac selection.** The redesign shows the zodiac stack as a decorative bundle only; tapping it is a no-op. A random `ZodiacSign` is injected once per `CreateRecordModel` instance so we can verify appearance. Real picker wiring is deferred; the existing `ZodiacPickerSheet.swift` stays on disk, unused.
- **`+ Person` top-right button.** Rendered for visual parity at opacity 0.35 (disabled). Behavior (2-person flow) is deferred to v1.1 per the design spec.
- **Photo layer tuning.** `CardBackdrop` simply delegates to the existing `PhotoLayer`; no changes to photo rendering.
- **Dynamic Type / Reduce Motion passes.** Plan 3.1 T10/T11 still own those; the new components should compose cleanly with them but we do not add Dynamic Type-specific layouts here.

## 4. Architecture

### 4.1 Shared backdrop extraction (`Visuals`)

`CardView.swift` currently contains a private `backdrop(accoutrements:density:layout:)` builder that stacks the atmospheric layers. We extract just the atmospheric portion into a new public view:

**New:** `Packages/Sources/Visuals/CardBackdrop.swift`
```swift
public struct CardBackdrop: View {
    public let record: Record
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let photo: Image?

    // Renders, in z-order:
    //   GradientLayer (time-of-day)
    //   GuillocheRotationLayer (letter rotation filigree)
    //   BBackgroundSilhouetteLayer (letter silhouette)
    //   PhotoLayer (if photo != nil) OR GuillocheBlendLayer (A/Polygon letter)
}
```

The zodiac constellation, holographic zodiac symbol, and moon phase layers **stay inside `CardView`** — they are part of the card's presentation, not the shared backdrop. The create flow does not use them; it renders its own versions with different positioning (see §4.3).

**Changed:** `CardView.swift` delegates its atmospheric stack to `CardBackdrop` and keeps its existing zodiac/moon overlays and `CardTextLayer` unchanged. No visible regression in card rendering.

### 4.2 Create feature module (`FeatureCreate`)

Replace the contents of `CreateRecordScene.swift` and `CreateFormFields.swift` with the following file layout:

```
FeatureCreate/
├── CreateRecordScene.swift           ← assembly (public entry point)
├── CreateRecordModel.swift           ← @Observable form state (existing, extended)
├── PersonTopNav.swift                ← Cancel | PERSON | + Person
├── CreateFormOverlay.swift           ← + Add Photo, name pill, description pill
├── LocationTimeStrip.swift           ← autofilled location + date/time strip
├── SaveButton.swift                  ← full-width gradient SAVE button
├── Badges/
│   ├── CreateConstellationBadge.swift    ← right-edge stars (100×90)
│   ├── CreateZodiacSymbolBadge.swift     ← holographic symbol (35×32)
│   └── CreateMoonPhaseBadge.swift        ← moon with hologram frame (35×56)
└── ZodiacPickerSheet.swift           ← unchanged; kept on disk for future wiring
```

`CreateFormFields.swift` is deleted.

### 4.3 Create-flow zodiac badges

The Figma `Zodiac_info` frame (`300:11442`, 100×127) stacks three elements on the right edge of the card:
- `Stars/Cancer` (constellation) — 100×90 at the top of the frame
- `Symbol/Cancer` (holographic symbol) — 35×32 bottom-left of the frame
- `Waning_Crescennt` (moon phase with hologram frame) — 35×56 bottom-right of the frame

These render visually differently from the card's own zodiac/moon (different sizes, different composition, moon phase's hologram frame is visible). We build three new sibling views in `FeatureCreate/Badges/` that load the existing SVG assets from the `Visuals` module directly via `Image(name:bundle: .module)`. They do **not** reuse `ZodiacLayer`/`HolographicZodiac`/`MoonPhaseLayer`. The SVG assets themselves are shared.

## 5. Screen composition

`CreateRecordScene` is presented by `AppFeature/RootScene.swift` via `.sheet(isPresented: $router.showingCreate)`. The default `.sheet` chrome supplies the drag handle and rounded-top corners.

```
ZStack(alignment: .top) {
    Color(CCDesign.Colors.lightL2)   // #E9EAF1 sheet background

    VStack(spacing: 0) {
        PersonTopNav(onCancel: onCancel)                        // 44pt

        ZStack(alignment: .topTrailing) {                       // card area, flexible height
            CardBackdrop(record: previewRecord,
                         attitude: attitude,
                         paths: paths,
                         photo: photoImage)

            ZStack(alignment: .topLeading) {                    // zodiac stack, 100×127 frame
                CreateConstellationBadge(sign: randomSign, attitude: attitude)
                    .frame(width: 100, height: 90)              // local (0, 0)
                CreateZodiacSymbolBadge(sign: randomSign, attitude: attitude)
                    .frame(width: 35, height: 32)
                    .offset(x: 52, y: 70)                       // Figma local (52, 70)
                CreateMoonPhaseBadge(phase: moonPhase)
                    .frame(width: 35, height: 56)
                    .offset(x: 57, y: 71)                       // Figma local (57, 71) — overlaps symbol
            }
            .frame(width: 100, height: 127)
            // Positioned top-trailing inside card with Figma's insets: frame origin
            // in card coords is (x=275, y=259) — i.e. right-aligned with top offset 259pt
            // from card top. In a flexible-height card this translates to alignment
            // guides; see implementation plan.

            CreateFormOverlay(model: model, onTapPhoto: handlePickPhoto)
        }

        LocationTimeStrip(location: model.location,
                          createdAt: model.createdAt,
                          timeOfDay: model.timeOfDay)           // 40pt

        SaveButton(isEnabled: model.isSaveable,
                   timeOfDay: model.timeOfDay,
                   attitude: attitude,
                   action: { onSave(model.draft) })             // 50pt

        Spacer()                                                // keyboard can push content up
    }
}
```

## 6. Data flow

### 6.1 `CreateRecordModel` changes

Extend the existing `@Observable @MainActor` model:

- **Add** `let createdAt: Date` — fixed at `init()`, non-editable, exposed for strip/preview.
- **Add** `let timeOfDay: TimeOfDay` — derived once from `createdAt` via existing `TimeOfDayService.current(for:)`.
- **Add** `let moonPhase: MoonPhase` — derived once from `createdAt` via existing `MoonPhaseService.phase(for:)`.
- **Add** `let randomZodiacSign: ZodiacSign` — generated once via `ZodiacSign.allCases.randomElement()!`. Visible-only until picker lands.
- **Narrow** `previewRecord` to use the above values; remove the hardcoded `.midday`/`.fullMoon`.
- **Remove** the `zodiacSign` editable path from public API (keep `randomZodiacSign` only). `draft` maps `randomZodiacSign` into `RecordDraft.zodiacSign` so saved records have a sign.

### 6.2 `CreateRecordScene` inputs

Signature stays compatible; one new callback is injected:

```swift
public init(
    attitude: DeviceAttitude,
    paths: any CardPathProvider,
    onCancel: @escaping () -> Void,
    onSave: @escaping (RecordDraft) -> Void,
    onPickPhoto: @escaping () async -> Data?    // NEW
)
```

`AppFeature/RootScene.swift` supplies `onPickPhoto` using the existing photo-picker service (same service used elsewhere in the app).

### 6.3 Photo flow

1. User taps `+ Add Photo` inside `CreateFormOverlay`.
2. Overlay calls `Task { model.photoData = await onPickPhoto() }`.
3. Model's `photoImage` computed property returns `Image(uiImage:)` when `photoData != nil`.
4. `CardBackdrop` receives the image and swaps `GuillocheBlendLayer` → `PhotoLayer` (existing conditional in `CardBackdrop`).

### 6.4 Save flow

Unchanged. `model.draft` → `onSave(draft)` → `AppFeature` persists via `RecordStore`. `SaveButton` is disabled when `!model.isSaveable`.

## 7. Visual tokens & pixel-level notes

All values are sourced from Figma node `185:8911`. Design tokens referenced by name (e.g. `Light/L2`) resolve via `DesignSystem.CCDesign.Colors`.

### 7.1 `PersonTopNav` (44pt × full width)

- Sheet chrome already provides the drag handle above this bar.
- `Cancel` — Cormorant Infant SemiBold 18, Light/L0 `#FFFFFF`, 16pt leading inset.
- `PERSON` heading — Cormorant SC Bold 16, tracking 2.4, uppercase, Light/L2 `#E9EAF1`, horizontally centered.
- `+ Person` — Cormorant Infant SemiBold 18, Light/L0, 16pt trailing inset, **opacity 0.35** (disabled placeholder). Not interactive.

### 7.2 `CreateFormOverlay` (inside card area)

- `+ Add Photo` — IBM Plex Mono Regular 11/12, Light/L0, 8pt leading. Positioned vertically just above the name pill.
- Name pill — Cormorant SC SemiBold 48/60, black, 16pt horizontal / 0 vertical padding. Background: solid white @ 56% with a `mix-blend-luminosity` overlay of the `imgName` / neon texture at opacity 0.35 on top, which produces the characteristic "glass window" look. Implement the solid white fill first; layer the luminosity-blend texture in a follow-up pass only if side-by-side comparison shows a meaningful gap. No border, no corner radius.
- **Name placeholder state** — when `model.name` is empty, the pill displays the literal string `Name` in the same Cormorant SC SemiBold 48 black text. Figma (`D_Add_new_Name_2P` node `300:11723`) shows placeholder and typed text in identical styling — the faded appearance in the mock comes from the luminosity-blend background, not a separate placeholder color. Implementation should therefore use SwiftUI `TextField("Name", text: $model.name)` with `.font(...)` + `.foregroundStyle(.black)`; SwiftUI's default placeholder behavior (secondary label color) is acceptable since it mirrors the visual fade Figma shows. **Do not** apply a manual opacity reduction to the placeholder — let the luminosity-blend backdrop do the work.
- Description pill — Cormorant Infant SemiBold 18/27, Light/L0. Reuses existing `BackdropBlurPill` with `fill: white@0.15`, border `white@0.45` 1px, 16pt horizontal / 9pt vertical padding.
- **Description placeholder state** — when `model.description` is empty, the pill shows `Description` in the same Cormorant Infant SemiBold 18 white text via `TextField`'s native placeholder behavior. Same rule as above: no manual opacity tweak.
- All three left-aligned at 8pt from the card's leading edge. Name and description pills `fixedSize` horizontally so their width hugs content (matches Figma pill-per-line treatment).

### 7.3 Zodiac badges (right-edge stack inside `Zodiac_info` 100×127)

- `CreateConstellationBadge` — 100×90, top of frame. Loads `{sign}_constellation` SVG from `Visuals` bundle. Attitude-driven parallax same as `ZodiacLayer` (4pt max translation).
- `CreateZodiacSymbolBadge` — 35×32, bottom-left of frame (Figma: local x=52, y=70). Holographic treatment: reuse `HolographicZodiac`'s masking approach — load `{sign}_figure` asset and apply the neon luminance mask.
- `CreateMoonPhaseBadge` — 35×56, bottom-right of frame (Figma: local x=57, y=71; overlaps symbol by ~30pt). Renders `Moon_Background` frame SVG with the 20×20 phase glyph pinned top-center at 7pt inset — identical inner structure to `MoonPhaseLayer` but written as its own file for clarity.

All three are `.accessibilityHidden(true)` (decorative).

### 7.4 `LocationTimeStrip` (40pt × 359pt, 8pt horizontal inset from screen)

- Background: `white@0.1` fill, `white@0.25` 1pt border (solid box; no corner radius per Figma).
- **Left half (~50% width):**
  - 16pt leading pad. Two-line address, Cormorant SC Bold 12/12 tracking 0.2 uppercase, Light/L0. Line 1 = first comma-separated segment; line 2 = remainder.
  - Hologram-masked location glyph 12×12 at right of the left half (right 8.19pt inset from the half's right edge).
- **Center:** 1pt × 38pt vertical separator at the 50% mark, white@0.25.
- **Right half:**
  - 15pt trailing pad / 7pt top pad. IBM Plex Mono Regular 11/12, Light/L0, right-aligned.
  - Line 1: `DateFormatter "MMM d, yyyy"` on `model.createdAt`.
  - Line 2: `"\(timeOfDay.rawValue.capitalized), \(h:mm a)"` with lowercase am/pm.

Example: `Aug 25, 2020` / `Sunset, 5:20 pm`.

### 7.5 `SaveButton` (50pt × full width)

- Background: `GradientLayer(timeOfDay: model.timeOfDay, attitude: attitude)` — same instance of the gradient used at the top of the card, so the button reads as a continuation.
- Text: "SAVE" Cormorant SC Bold 16/20 tracking 2.4 uppercase, Light/L0, horizontally centered.
- Disabled state (`!model.isSaveable`): opacity 0.35 on both background and text.
- Tappable only when enabled.

### 7.6 Sheet chrome & backdrop

- Presentation: `.sheet(isPresented:)` as today.
- Rely on default drag handle and rounded-top corners (iOS 16+).
- The outer `#dee0e7`-tinted rectangle visible at the very top of the Figma mock represents the previous screen (list view) peeking behind the sheet. That is supplied by the system; we do not render it ourselves.
- Root VStack background: Light/L2 `#E9EAF1` — only visible in the narrow gap between the card area and the keyboard (if any) during active editing.

## 8. Testing strategy

### 8.1 Host-side (`swift test`)

- **Extend `CreateRecordModelTests`:**
  - `createdAt` is fixed at init; does not change across reads.
  - `timeOfDay` and `moonPhase` are derived consistently from `createdAt`.
  - `randomZodiacSign` is one of `ZodiacSign.allCases` and stable within an instance.
  - `draft.zodiacSign == randomZodiacSign`.
  - `isSaveable` toggles with whitespace trimming on `name`.
- **New `LocationTimeStripFormatterTests`:**
  - `MMM d, yyyy` and `h:mm a` output for representative dates.
  - `"Sunset, 5:20 pm"` composite string exact match.
  - Two-line address split (comma-separated).

### 8.2 Simulator snapshot (`xcodebuild test` iPhone 17)

Seed randomness via an injected `zodiacSign` override in previews/tests so snapshots are deterministic.

- **`CreateRecordSceneSnapshotTests`:**
  - Empty state (no name, no description, no photo).
  - Filled: name "Adam", description "Met at Midday".
  - Photo attached (blend letter replaced by photo).
  - Save disabled vs enabled.
  - `+ Person` disabled visual.
- **`CreateZodiacBadgeSnapshotTests`:** each of the three badges rendered independently at their target sizes, for at least two signs and two moon phases.

### 8.3 View-behavior tests (`@MainActor` Swift Testing)

- Tap `+ Add Photo` → `onPickPhoto` called exactly once.
- Edit name to non-empty → `isSaveable` becomes true → save button becomes enabled.
- `+ Person` button reports `.isButton` trait but `.isEnabled == false`.
- Zodiac badges have no `.isButton` trait (decorative).

### 8.4 Not covered (scope-matching existing plans)

- XCUITest end-to-end flow — stays Plan 3.1 T13.
- Dynamic Type / Reduce Motion — stays Plan 3.1 T10/T11.
- 2-person flow — deferred v1.1.
- Zodiac picker wiring — deferred.

## 9. Implementation notes for the plan

- Swift 6 strict concurrency: annotate new views / test suites with `@MainActor` when accessing view bodies.
- iOS-only APIs (`.presentationDetents`, `.sheet` photo picker helpers) guarded with `#if os(iOS)` per existing convention.
- New `CardBackdrop` must compile on macOS host (for `swift test`). It already does — none of the atmospheric layers are iOS-only.
- SVG assets (`{sign}_constellation`, `{sign}_figure`, `Moon_Background`, `{MoonPhase}`) are already in the `Visuals` asset catalog (`Packages/Sources/Visuals/Resources/`). The badges load them from `bundle: .module` of the `Visuals` module by exposing a public `Bundle` accessor, or — simpler — the badge components live inside `Visuals` and are re-exported for `FeatureCreate` to compose. Decision for the plan: **keep badges in `FeatureCreate` and add a `public static let bundle: Bundle = .module` accessor on `Visuals`**.
- `CreateRecordScene` keeps `@Bindable` usage and pure SwiftUI — no UIKit reach-throughs.

## 10. Open questions

None at spec time. Any Figma gap discovered during implementation (e.g. pressed states, empty-location state) is a stop sign per `CLAUDE.md` §"Ambiguity is a stop sign" — surface and ask, do not invent.
