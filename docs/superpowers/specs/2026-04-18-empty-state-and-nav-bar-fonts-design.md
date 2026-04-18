# Empty State + Nav Bar Fonts — Design

**Date:** 2026-04-18
**Scope:** Bring the `RecordsListScene` empty state and navigation bar title in line with the Figma reference. Small, focused polish task — one spec, one plan.

## Figma references

- **Light empty state:** `L_Collection_View_Empty` — node `335:15455`
- **Dark empty state:** `D_Collection_View_Empty` — node `335:13907`
- **Populated collection view (for nav-bar reference):** `L_Collection_View` — node `3:215`

File key: `aYjd42Fr66HRCV0vQcJAtS`.

## What ships today

- `EmptyStateView` (Packages/Sources/FeatureList/EmptyStateView.swift) shows the sunset gradient with a placeholder `RoundedRectangle` glyph, the title "No one here yet", and the subtitle "Tap + to record your first contact".
- `RecordsListScene` uses `.navigationTitle("My Contacts")` — iOS default system font.
- Search bar is visible on empty and populated states alike.

## What Figma specifies

### Empty state composition (bottom-to-top)

1. **Sunset gradient** — full screen (already correct).
2. **`A/Background` guilloche rotation pattern** — the 78-line filigree circle for the letter `A`. Size 380×380, x≈-3, y≈216 (pattern hangs slightly off the left edge). Opacity ~13-16%, rendered in white.
3. **`A/Polygon` guilloche blend pattern** — the hexagonal "A" centerpiece. Size 167.428×145, centered horizontally near y≈334. Opacity ~55-60%, rendered in white.
4. **Title pill** — a translucent white bar (`rgba(255, 255, 255, 0.56)` + ~27 px backdrop blur with luminosity blend) containing the text **"add the first person"** in Cormorant SC SemiBold 33 pt, black, lowercase, centered. The pill has 6 pt horizontal padding and sits inside a 316 pt-wide frame at x=29, y≈390.
5. **Floating `+` button** — already present in `RecordsListScene`, unchanged.
6. **Search bar is hidden** on the empty state (there is nothing to search).

### Navigation bar

The shared `Nav_Bar` component has **three styling variants** in Figma, driven by the state of the collection view:

| State | Nav bar bg | Title color | Source node |
|---|---|---|---|
| Empty (both modes) | transparent, 10 px blur | `#FFFFFF` (white) | `421:13621` |
| Populated — Light | `CCDesign.Colors.L2` (#E9EAF1) at 80% opacity, 10 px blur | `CCDesign.Colors.D4` (#141415) | `45:4392` |
| Populated — Dark | transparent, 10 px blur | `CCDesign.Colors.L2` (#E9EAF1) | `277:12853` |

Title typography is identical across all three: **"MY CONTACTS"** — Cormorant SC Bold 16 pt, tracking 2.4, uppercase. Only bar background and text color change.

The sorting toggle (left-side up/down-arrow glyph) visible in Figma's populated states is tied to the deferred default/advanced sorting screens; it is **out of scope** for this task and omitted per the v1.1+ deferrals in CLAUDE.md. Only the title and the existing ellipsis/settings trailing item stay.

## Changes

### `EmptyStateView` (Packages/Sources/FeatureList/EmptyStateView.swift)

- Accept a `CardPathProvider` via init so the view can draw guilloche paths. `RecordsListScene` already receives one; it passes it in.
- Compose:
  - `CCDesign.Gradients.sunset` full-bleed (existing).
  - `GuillocheRotationLayer(paths: paths.rotationPaths(for: "A"), opacity: 0.13, tint: .white)` sized 380×380, offset to match Figma (x=-3, y=216 on a 375-wide canvas → approximately `.offset(x: -3, y: -30)` relative to center of screen, but specified as absolute positioning).
  - `GuillocheBlendLayer(paths: paths.blendPaths(for: "A", shape: .polygon, density: .card), attitude: .zero, tint: .white)` wrapped with `.opacity(0.55)`, sized 167.428×145, roughly centered horizontally and placed at y≈334 pt from top.
  - A translucent white pill containing `Text("add the first person")` with `CCDesign.Typography.title` (Cormorant SC SemiBold 33). Foreground black. `.accessibilityIdentifier("emptyStateTitle")`.
- No subtitle.
- All decorative layers marked `.accessibilityHidden(true)`.
- Deliberately **not** honoring `DeviceAttitude` on the empty state — the Figma reference is static. Pass `.zero` to `GuillocheBlendLayer`.

### Pill background implementation

Figma specifies the pill as a 56% white solid fill + a 27 px `backdrop-blur` layer with `mix-blend-luminosity` at 35% opacity, with black text on top. The design-spec PDF (section 5) only prescribes the two-layer lighten/luminosity hologram treatment for *card titles* (animated), not for the empty-state pill — so the pill is **static**, no gyroscope response.

**Chosen approach (option 1): SwiftUI `.ultraThinMaterial` + white tint.**

```swift
Text("add the first person")
    .font(CCDesign.Typography.title)
    .foregroundStyle(.black)
    .padding(.horizontal, 6)
    .background(.ultraThinMaterial)
    .overlay(Color.white.opacity(0.2).allowsHitTesting(false))
    .accessibilityIdentifier("emptyStateTitle")
```

`.ultraThinMaterial` provides a real backdrop blur + tint natively on iOS, matching the "frosted translucent bar" look. It won't match Figma's exact 27 px blur radius or luminosity blend pixel-for-pixel, but reads as the same visual language.

**Fallback options if option 1 looks wrong:**

- **Option 2 — `UIViewRepresentable` wrapping `UIVisualEffectView`.** Gives us access to `UIBlurEffect.Style.systemUltraThinMaterial`, `.systemMaterial`, etc. Still can't set an arbitrary blur radius without private APIs. Worth trying if `.ultraThinMaterial` reads too opaque or too clear.
- **Option 3 — Metal shader via `.colorEffect` / `.visualEffect` (iOS 17+).** Pixel-exact luminosity blend + controlled blur radius. Significant code, ongoing maintenance. Last-resort if the pill is a focal visual and options 1–2 can't match Figma.

Positioning: place the pill with a top padding of ~390 pt from the top of the safe area (using a `VStack` + `Spacer` combo scaled to screen height avoids hardcoding). We will match the Figma y-coordinate proportionally by using a layout like:

```swift
GeometryReader { geo in
    ZStack(alignment: .top) {
        // gradient
        // guilloche layers
        // pill positioned via .position() or .offset()
    }
}
```

### `RecordsListScene` (Packages/Sources/FeatureList/RecordsListScene.swift)

- Remove `.navigationTitle("My Contacts")`.
- Add `.toolbar { ToolbarItem(placement: .principal) { Text("MY CONTACTS").font(CCDesign.Typography.headline).tracking(CCDesign.Typography.Tracking.headline).foregroundStyle(isEmpty ? .white : CCDesign.Colors.D4) } }` where `isEmpty = store.records.isEmpty`.
- Branch title color + bar surface on `(isEmpty, colorScheme)`:
  - `isEmpty == true` → title `.white`, `.toolbarBackground(.hidden, for: .navigationBar)` so the sunset shows through.
  - `isEmpty == false && colorScheme == .light` → title `CCDesign.Colors.D4`, `.toolbarBackground(CCDesign.Colors.L2.opacity(0.8), for: .navigationBar)` + `.toolbarBackground(.visible, for: .navigationBar)`.
  - `isEmpty == false && colorScheme == .dark` → title `CCDesign.Colors.L2`, `.toolbarBackground(.hidden, for: .navigationBar)`.
- Inject `@Environment(\.colorScheme) private var colorScheme` in `RecordsListScene`.
- Keep `.navigationBarTitleDisplayMode(.inline)` (iOS-only).
- Only apply `.searchable` when `!store.records.isEmpty`.
- Pass the `paths` provider down to `EmptyStateView(paths: paths)`.
- macOS fallback for the principal toolbar slot: same `Text` using `.primaryAction` placement, or skip — keep parity with existing macOS fallbacks in the file (search usage is already gated).

### Test updates

- `Packages/Tests/FeatureListTests/RecordsListTests.swift` — `emptyStateViewInstantiates` now needs a `CardPathProvider`. Use `RealCardPathProvider()`.
- `CasualContacts/CasualContactsUITests/CasualContactsUITests.swift` — update the assertion `XCTAssertEqual(emptyTitle.label, "No one here yet")` to `"add the first person"`. (The accessibility identifier `emptyStateTitle` stays.)

### Files touched

- `Packages/Sources/FeatureList/EmptyStateView.swift` — rewrite.
- `Packages/Sources/FeatureList/RecordsListScene.swift` — toolbar customization, conditional `.searchable`, pass `paths` to empty state.
- `Packages/Tests/FeatureListTests/RecordsListTests.swift` — update the single call site.
- `CasualContacts/CasualContactsUITests/CasualContactsUITests.swift` — update the label assertion.

No changes to `DesignSystem`, `Visuals`, `AppFeature`, or the Storage/Services targets.

## Non-goals

- No new sort controls, no recommended section. Those are deferred per plan 3.1 and the v1.1+ list in CLAUDE.md.
- No dark-mode-specific styling. The empty state is already the sunset gradient in both modes per Figma.
- No attitude-driven parallax on the empty-state guilloche — Figma shows it static.

## Testing plan

1. `swift test` in `Packages/` — expected to stay green after updating the `EmptyStateView` init call site.
2. Visual spot-check on iPhone 17 simulator with empty store: verify the A guilloche filigree and polygon render, the "add the first person" pill is positioned where Figma shows it, nav bar reads "MY CONTACTS" in Cormorant SC Bold uppercase with tracking 2.4.
3. Visual spot-check with one record added: search bar reappears, nav bar still "MY CONTACTS".
4. UI test `CasualContactsUITests` — first-launch assertion updated, rerun on simulator.

## Risks

- **Font not resolving at runtime.** CLAUDE.md flags this as a known rough edge. The nav-bar custom font is the first in-app consumer of `CCDesign.Typography.headline` in navigation chrome, so if the font fails to resolve the user will see it immediately and we'll know early.
- **Guilloche positioning on different screen heights.** iPhone 17 is 852 pt tall; Figma artboard is 812 pt. Using proportional layout (not hardcoded pt) keeps the composition stable across device sizes.
