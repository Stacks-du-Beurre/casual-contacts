# Design reference — Figma layer map + designer techniques

Reference data for UI work. The **10 design fidelity directives** (Figma canonical, don't cut corners, reuse primitives, verify visually, etc.) live in `CLAUDE.md` and apply to every session — this doc is the map and the how-to.

- **Figma file:** [Casual Contacts](https://www.figma.com/design/aYjd42Fr66HRCV0vQcJAtS/Casual-Contacts)
- **File key:** `aYjd42Fr66HRCV0vQcJAtS`
- **Figma account:** `hello@therealadammork.com`
- **Access via:** the Figma MCP — `get_design_context`, `get_screenshot`, `get_metadata`.

## Light vs Dark

Every screen has both `L_` (Light) and `D_` (Dark) frames. The app ships dark-first (background `#141415`, Dark/D4 token), so **Dark is primary**; Light is listed in parens. Use the Dark node unless explicitly building a light variant.

**Chrome inverts per mode** — title text, nav-bar right-item fill, and FAB fill always use the mode's *primary* color (L2 on dark, D4 on light); the inner glyph detail (ellipsis dots, `+`) uses the inverse *accent* (D4 on dark, L2 on light). The populated-list background tracks the mode (D4 on dark, L2 on light). The empty state's sunset gradient does **not** change across modes — only its chrome flips.

## Reference viewport & device scaling

Every Figma frame in this file is authored at **375 × 812 pt** — the iPhone X / XS / 11 Pro / 12 mini / 13 mini viewport (first shipped with iPhone X, 2017). The designer's spec PDF is dated Jan 2021, so the canonical target was **iPhone 11 Pro**. Modern iPhones are larger.

| Device | Logical size (pt) | Width Δ | Height Δ | Top safe area |
|---|---|---|---|---|
| iPhone 11 Pro (canonical) | 375 × 812 | 1.000× | 1.000× | 44 (notch) |
| iPhone 15 / 16 / 17 | 402 × 874 | 1.072× | 1.076× | 59 (Dynamic Island) |
| iPhone 15 / 16 / 17 Pro Max | 440 × 956 | 1.173× | 1.177× | 59 (Dynamic Island) |
| iPhone SE (3rd gen) | 375 × 667 | 1.000× | 0.821× | 20 (no notch) |

Bottom home-indicator area is 34 pt across all notched devices; 0 on iPhone SE.

### What stays fixed vs what scales

**Fixed (same pt across every device):**
- **Touch targets** — FAB 56 pt; nav right-item circle 24 pt; nav bar 44 pt; hit-areas ≥ 44 pt per Apple HIG. These are gesture targets, not layout.
- **Edge gutters** — 16 pt horizontal padding (iOS convention; do not scale with width).
- **Font pt sizes** — Cormorant SC headline 16, title 33, IBM Plex Mono 13; always authored in pt via `CCDesign.Typography` tokens. Dynamic Type scales these through the system, not through device size.
- **Icon detail weights** — ellipsis dot size, `+` stroke width, guilloche stroke. A 2 pt line at 11 Pro reads identically at 17 Pro Max.

**Flexes with the device:**
- **Card / row widths** — use `.frame(maxWidth: .infinity).padding(.horizontal, 16)`. On 11 Pro → 343 pt; on 17 → 370 pt; on 17 Pro Max → 408 pt.
- **Background / gradient layers** — `.ignoresSafeArea()` + `.frame(maxWidth: .infinity, maxHeight: .infinity)` so they fill any screen.
- **Decorative art (guilloche, zodiac, moon)** — render at intrinsic Figma size (e.g. 380 × 380) and center; let empty space grow around it on wider devices. Don't stretch. Don't shrink to fit either — the designer's stroke weights are tuned for the absolute size.
- **Vertical element positions** — use `Spacer()`, `.frame(maxHeight: .infinity, alignment: .top/.bottom)`, or `.safeAreaInset(...)`. Never position by absolute y-offset from Figma.

### Right / wrong patterns

**Wrong — hardcoded position from Figma's 11 Pro coords:**
```swift
AddButton(...).position(x: 323, y: 734)   // Figma coords
```
Lands in the middle of the screen on iPhone 17.

**Right — relative anchoring:**
```swift
ZStack(alignment: .bottomTrailing) {
    content
    AddButton(...).padding(16)
}
```

**Wrong — hardcoded card width from Figma:**
```swift
SmallCard(...).frame(width: 343)   // leaves a gap on anything wider than 11 Pro
```

**Right — flex width + fixed gutter:**
```swift
SmallCard(...).frame(maxWidth: .infinity).padding(.horizontal, 16)
```

**Wrong — absolute y for the nav bar:**
```swift
CustomNavBar().offset(y: 44)   // assumes 11 Pro notch
```

**Right — use the safe area:**
```swift
content.safeAreaInset(edge: .top, spacing: 0) { CustomNavBar() }
```
Pushes below whatever the device's actual top safe area is (44 on 11 Pro, 59 on 17).

### Reading Figma screenshots for verification

When comparing simulator output to a Figma screenshot:
1. The Figma screenshot is 375 pt wide; your simulator is probably 402 or 440 pt. Elements will occupy a smaller *percentage* of the screen — that's correct.
2. Bug signals: element-to-element *ratios* change (e.g. FAB no longer 16 pt from the bottom-right; title not centered; card rows bleeding into the safe area).
3. Not-a-bug signals: more whitespace around decorative art, wider gutters, slightly taller ScrollView.

### Testing matrix

Verify each new screen on at least:
- **iPhone SE (3rd gen)** — narrow + short, no notch; catches SafeArea assumptions.
- **iPhone 11 Pro / 12 mini** — canonical reference; implementation should match Figma 1:1 here.
- **iPhone 17** — current default; catches hardcoded-width assumptions.
- **iPhone 17 Pro Max** — widest; catches decorative art that looks lost in whitespace.

Xcode previews with `.previewDevice("iPhone SE (3rd generation)")` etc. cover this cheaply during iteration.

## Screens

| Screen | Figma layer | Node ID |
|---|---|---|
| Launch screen | `L_Splash_Screen` | `335:15321` |
| List — empty state | `D_Collection_View_Empty` (light: `L_Collection_View_Empty` `335:15455`) | `335:13907` |
| List — populated | `D_Collection_View` (light: `L_Collection_View` `3:215`) | `277:12836` |
| Create — name only | `D_Add_new_Name_1P` (light: `L_Add_new_Name_1P` `185:8911`) | `284:66` |
| Create — name + photo | `D_Add_new_Name_1P&Photo` | `335:12388` |
| Create — 2-person *(deferred to v1.1)* | `D_Add_new_Name_2P` | `300:11705` |
| Settings (bottom sheet / context menu) | `D_Context_Menu` (light: `L_Context_Menu` `169:0`) | `277:12855` |
| Default Sorting *(deferred)* | `D_Default_Sorting` (light: `L_Default_Sorting` `209:9048`) | `278:10897` |
| Advanced Sorting *(deferred)* | `D_Advanced_Sorting` (light: `L_Advanced_Sorting` `189:155`) | `283:0` |

## App assets

| Asset | Figma layer | Node ID |
|---|---|---|
| App icon | `Icon/Large` | `388:13592` |

**Designer's notes (app icon)** — from `docs/CC Design Specifications.pdf` §7:
- Two icon variants: **small** and **large**.
- **Small icons (< 60px) must be filled** (solid glyph, no line work) for face recognition at small sizes. iOS 14+ sizes 20pt @1x, 29pt, 40pt — all filled variants.
- **Large icons** (iPhone app 60pt @2x/@3x, iPad 83.5pt @2x, App Store 1024×1024) use the **line-work C** with the stroked right-edge detail visible.
- Group in Figma is labeled "Cards" per the PDF — export from there before generating iOS asset-catalog sizes.

**Exported assets:**
- App icon: `CasualContacts/CasualContacts/Assets.xcassets/AppIcon.appiconset/` — `AppIcon.png`, `AppIcon-Dark.png`, `AppIcon-Tinted.png`, plus `Contents.json`. The asset catalog *is* the export; no parallel copies live under `design-assets/`.
- Launch logo: `CasualContacts/CasualContacts/Assets.xcassets/LaunchLogo.imageset/` — `LaunchLogo.png`, `LaunchLogo@2x.png`, `LaunchLogo@3x.png`.

## Card variants (`Light_Cards` frame `9:118`)

| Variant | Figma layer | Node ID |
|---|---|---|
| Full-width card, no photo (list row) | `Cards/Full` | `6:16` |
| Full-width card, with photo (list row) | `Cards/Full_w_Photo` | `39:828` |
| Recommended card | `Cards/Recommended` | `59:4544` |
| Recommended card with photo | `Cards/Recommended_w_Photo` | `72:3075` |
| Empty card (used in create flow) | `Cards/Empty` | `284:603` |

**Designer's notes (photo treatments)** — from `docs/CC Design Specifications.pdf` §5 "Photo":

- **Collection View (list-row cards with photo)**: photo rendered with `luminosity` blend mode over the time-of-day gradient, transparency in the **45–75%** range (designer left exact value unpinned — tune against a real photo, don't hard-code without eyeballing).
- **Recommended Section (small cards with photo)**: "glitch" effect — **two stacked copies** of the same photo:
  - Bottom copy: `luminosity` blend.
  - Top copy: `color` blend.
- Without a photo, the Recommended card falls back to a guilloche pattern in the same circular slot (§1 Blend tool techniques apply).
- Photos are rendered inside a circular mask for Recommended; for full-width list cards they're rectangular but tinted by the gradient underneath.

## Components (`Components` page `3:2`)

Light symbols: frame `Light_Nav_Symbols` `9:115`. Dark symbols: frame `Dark_Nav_Symbols` `106:2442`. Node IDs below are Light unless noted.

| Component | Figma layer | Node ID |
|---|---|---|
| FAB (+ button) | `Add_btn` | `44:11214` (dark `106:2486`) |
| Nav bar | `Nav_Bar` | `45:4391` (dark `106:2503`) |
| Search bar | `Search_Bar` | `45:4431` (dark `106:2551`) |
| Status bar | `Status_Bar` | `3:389` (dark `106:2528`) |
| Home indicator | `Home_Indicator` | `3:392` (dark `106:2493`) |
| Left action (cancel / back) | `Left_Action` | `284:6795` (dark-only) |
| Right action (save) | `Right_Action` | `299:14273` (dark-only) |
| Save button | `Save` | `293:11600` |
| Save (text variant) | `Save_Text` | `299:14280` |
| Cancel | `Cancel` | `284:4291` |
| Close | `Close` | `170:15` |
| Add Person button | `Add_Person` | `293:11621` |
| Add (icon) | `Add` | `223:7` |
| Delete | `Delete` | `223:4` |
| Switch | `Switch` | `180:37` |
| Star | `Star` | `180:64` |
| Share | `Share` | `180:66` |
| Arrow | `Arrow` | `180:75` |
| Grabber (drag handle) | `Grabber` | `204:17` |
| Keyboard | `Keyboard` | `274:10368` |
| Item — drag & drop row | `Item_Drag&Drop` | `279:20` |
| Item — add row | `Item_Add` | `279:181` |
| Action bar | `Action_Bar` | `284:4151` |
| Location & time label | `Location&Time` | `299:13934` (dark-only) |
| Safe bottom action button | `Safe_Btn` | `284:6815` (dark-only) |
| View controller button | `View_Controller` | `215:8` |
| Sorting button | `Sorting` | `189:150` |
| Location icon | `Location` | `44:10869` |

## Design tokens

| Group | Figma layer | Node ID |
|---|---|---|
| Colors (L0–L4, D0–D4) | `Colors` frame | `277:11175` |
| Typography (Cormorant, IBM Plex Mono) | `Typography` frame | `277:11865` |

**Exported assets (fonts):** `design-assets/fonts/` ships four TTFs used by the Typography tokens — `CormorantInfant-Variable.ttf` (variable axis), `CormorantSC-Bold.ttf`, `CormorantSC-SemiBold.ttf`, `IBMPlexMono-Regular.ttf`. Licenses in `design-assets/fonts/LICENSES`. Register at launch via `FontRegistration`.

## Gradients — time-of-day (`Gradients` frame `9:116`)

| Gradient | Node ID |
|---|---|
| Sunrise | `343:22` |
| Dawn | `343:26` |
| Midday | `10:4` |
| Sunset | `10:3` |
| Dusk | `31:4` |
| Night | `39:4` |
| Midnight | `343:30` |

**Designer's notes (gradients)** — from `docs/CC Design Specifications.pdf` §2:
- Seven backgrounds cover the full day: Dawn, Sunrise, Midday, Sunset, Dusk, Night, Midnight. Each is a hand-authored **painterly bitmap** (not a procedural linear ramp), with enough contrast to carry white text directly on it.
- **Transfusion effect** (parallax on gyroscope): stack **two identical gradient bitmaps**. Hold the bottom fully opaque; animate the **top layer's opacity from 0 → 100%** based on the device's gyroscope / attitude. The result reads as a liquid, metallic shift as the phone tilts — because the top and bottom are the same image, the shift reveals internal color regions of the bitmap rather than just dimming.
- **Resting / reduced-motion state:** `GradientLayer.transfusionOpacity` computes `abs(attitude.roll)`. With `attitude.roll = 0` (phone level *or* the `ReducedMotionAdapter` zeroing the input), top opacity lands at **0** — only the bottom bitmap is visible (single-gradient look). Tilting in either direction raises the rotated top layer: `|roll| = 0.5` → 50/50 blend, `|roll| = 1` → top layer fully covers (other gradient 100%).
- **Reduce Transparency:** `GradientLayer` observes `@Environment(\.accessibilityReduceTransparency)`. When on, the top layer is omitted entirely and the bottom bitmap renders alone (no translucent overlay).

**Exported assets:**
- **Source PNGs:** `design-assets/Gradients/{Dawn,Sunrise,Midday,Sunset,Dusk,Night,Midnight}.png` (7 files, 689×416 each).
- **Shipped catalog:** `Packages/Sources/DesignSystem/Resources/Gradients.xcassets/` — 7 imagesets wrapping the same PNGs. Resolved at runtime via `Bundle.module` through `CCDesign.GradientBackdrop`; `CCDesign.Gradients.view(for: TimeOfDay)` dispatches to the right bitmap.

## Guilloche patterns (`Guilloche_Patterns` frame `15:30`)

| Pattern | Node ID |
|---|---|
| A/Background | `30:75` |
| A/Polygon | `30:582` |
| A/Small | `72:2236` |
| B/Background | `15:1147` |
| B/pattern | `17:41316` |
| B/Small | `72:636` |
| I/Background | `34:1194` |
| I/Polygon | `34:1430` |
| I/Small | `72:2239` |
| S/Background | `39:80` |
| S/Elipse | `39:338` |
| S/Small | `72:2238` |

**Designer's notes (guilloche)** — from `docs/CC Design Specifications.pdf` §1:

Alphabetical guilloche patterns are built with two complementary Illustrator techniques. The app uses both — one for ambient backgrounds, one for the identity glyph on each card.

**1. Rotation (background patterns)** — §1.2
- Source SVGs live in `design-assets/Guilloche/App/Rotation/{Latin,Cyrillic}/`. Each character is pre-shaped so its centroid lies at a point that, when rotated around, yields the correct guilloche.
- Stroke CSS (reference): `fill: none; stroke: #000; stroke-miterlimit: 10; stroke-width: 0.5px; transform-origin: center;`
- Per copy, rotate **5°**. Stacking ~72 copies produces one full 360° rosette. Stroke width is *dynamic* across the stack (varies per copy) — that's what gives the "weight" pulse.
- In the app this is `GuillocheRotationLayer`. See `Tools/SVGToSwift/` + `Tools/regenerate-svg.sh` for the SVG-to-Swift pipeline.

**2. Blend tool / "Path to" (letter-to-shape morph, foreground glyph)** — §1.3
- The letter (26 of them: A–Z) morphs to one of **3 shapes**: Circle, Square, Polygon (hexagon).
- Two line counts by context:
  - **Recommended Section** (small 100×95 cards): **1 shape + 7 transition lines**.
  - **Cards** (full-width list cards + detail): **3 shapes + 15 transition lines**.
- **Deep-dive effect** (foreground z-motion): each transition line is exported as its own layer on the same artboard. To animate depth, translate each layer independently by `(x, y)` — layers closer to the "shape" end move more than layers closer to the letter, creating parallax into/out of the card.
- Source filename convention: `A_C_0.svg` = Letter **A**, Shape **C**ircle, Position/Spline **0**. Preserve the letter/shape/index naming end-to-end; rendering picks the right triplet from the record's initial + card size + state.
- In the app this is `GuillocheBlendLayer`. Generated Swift files land in `Packages/Sources/Visuals/Guilloche/Generated/` (gitignored); regenerate via `./Tools/regenerate-svg.sh`.

**Exported assets (guilloche):**
- **Rotation sources (§1.2)** — `design-assets/Guilloche/App/Rotation/Latin/{A–Z}_Rotation.svg` and `design-assets/Guilloche/App/Rotation/Cyrillic/Uxxxx_Rotation.svg`. Stroke CSS lives inline on each path; the rotation pipeline multiplies these by ~72 to build the rosette.
- **Blend per-line layers (§1.3, deep-dive source)** — `design-assets/Blended/{A,B,C}/Circle/{Letter}_C_{0–16}.svg`, `…/Square/{Letter}_S_{0–16}.svg`, `…/Polygon/{Letter}_P_{0–16}.svg`, `…/Circle_for_Preview_Section/{Letter}_Pre_{0–8}.svg`. Only **A, B, C** are exported per-line ("3 letters for test" in the PDF). Each indexed file is one transition line; stack them on the same 100% artboard to drive deep-dive translation.
- **Blend flat composites** — `design-assets/Guilloche/App/Blend/Latin/{A–Z}_{Circle,Square,Polygon}.svg` + `{A–Z}_Preview.svg` and `design-assets/Guilloche/App/Blend/Cyrillic/Uxxxx_{Circle,Square,Polygon}.svg`. Each SVG is the full stack already merged — no deep-dive motion, but usable as a static fallback or for the Recommended small card.
- **Source (master)** — `design-assets/Blended_Letters.ai` (Adobe Illustrator) is the designer's working file; regenerate per-line and composite SVGs from it if the full A–Z per-line set is ever needed.

## Holograms (`Holograms` frame `51:6377`)

| Hologram | Node ID |
|---|---|
| Neon/1 | `72:3159` |
| Neon/2 | `72:3161` |
| Neon/3 | `72:3378` |
| Neon/4 | `72:3386` |

**Designer's notes (holograms)** — from `docs/CC Design Specifications.pdf` §5:

Three on-card elements use the hologram treatment: **Title/Name**, **Location**, **Zodiac sign**. Each uses a different blend-mode stack and motion binding. The PDF explicitly says "I used the simplest ways (rotation + different color blending models) to achieve the effect of transfusion, but maybe you can find more efficient ways" — treat these stacks as reference, not sacred, but ship the exact visible result.

**Title / Name** (`HolographicText.swift`)
- Two stacked layers of the name text:
  - **Bottom layer:** blend mode `lighten`. **Motion:** translate along `(x, y)` from attitude.
  - **Top layer:** blend mode `luminosity`. **Motion:** rotate (small angle) from attitude.
- Transfusion comes from the interplay: the bottom slides under the top, the top's rotation shifts which part of the underlying hologram shows through.

**Location** (`HolographicLocation.swift`)
- Two stacked layers of the location string:
  - **Bottom layer:** blurred copy. **Motion:** translate along `(x, y)` based on horoscope (zodiac) offset, *not* raw attitude.
  - **Top layer:** sharp copy, static.
- The blurred bottom gives the location a chromatic-fringe halo that moves independently.

**Zodiac sign** (`HolographicZodiac.swift`)
- Single hologram-image layer. **Motion:** translate along `(x, y)` from attitude. No rotation, no second layer.

**Reduce Transparency fallback** — `@Environment(\.accessibilityReduceTransparency)` collapses all three stacks to a solid-white single layer (no blend modes, no motion), as required by Plan 3.1 T11.

**Exported assets:**
- `design-assets/Holograms/Neon_1.jpg` (1300×866, JPEG) — pulled from Figma symbol `Neon/1` `72:3159`.
- `design-assets/Holograms/Neon_2.jpg` (800×533, JPEG) — from `Neon/2` `72:3161`.
- `design-assets/Holograms/Neon_3.png` (338×338, PNG RGBA) — from `Neon/3` `72:3378`.
- `design-assets/Holograms/Neon_4.png` (626×416, PNG RGBA) — from `Neon/4` `72:3386`.

**How these are used** — the Neon assets are the **background / base layer** that sits *under* the Title, Location, and Zodiac text. The blend-mode stack (`lighten` / `luminosity` / `color` for each object) composes the foreground text *onto* the hologram — the iridescent sheen you see through the letter shapes is the Neon image showing through via the blend. Each of the three objects (Title, Location, Zodiac) has its own Neon tile; Figma pairs `Neon/1–4` roughly one per object plus a spare, but the code decides which Neon variant to use per card.

**Swift rendering note** — the PDF's blend stacks (`lighten` bottom + `luminosity` top for Title, `blur` + translate for Location, single-image translate for Zodiac) are authored as *Figma blend modes over raster bitmaps*. SwiftUI's `.blendMode(.lighten)` / `.luminosity` / `.color` match the Core Graphics names, but achieving the exact Figma composite may require: isolating the stack with `.compositingGroup()` so blends don't leak into the card background, masking to the glyph with `.mask(Text(...))`, and in some cases falling back to `Canvas` with explicit `GraphicsContext.BlendMode` for the `color` mode on photo cards (which behaves differently than Figma's `color` for images that contain transparency). **If a blend result doesn't match the Figma screenshot, stop and ask** — do not substitute a `LinearGradient` or hand-tinted overlay for an actual blend-mode composite. The designer's explicit note ("maybe you can find more efficient ways") grants freedom on *how*, not on *whether the end pixels match*.

## Moon phases (`Moon` frame `11:477`)

All eight phases live as symbols under this frame, in order:

1. `New_Moon`
2. `Waxing_Crescennt` *(sic — see Quirks)*
3. `First_Quarter`
4. `Waxing_Gibbous`
5. `Full_Moon`
6. `Waning_Gibbous`
7. `Third_Quarter`
8. `Waning_Crescennt` *(sic)*

**Designer's notes (moon)** — from `docs/CC Design Specifications.pdf` §4: phase is computed from the record's `createdAt` timestamp and rendered as a light-on-dark symbol beside the zodiac info on the card. The preserved double-n `Crescennt` spelling is a source-filename quirk; `MoonPhase` enum uses correct spelling and `MoonPhaseLayer.assetName(for:)` maps between them.

**Exported assets:** `design-assets/Moon_Phases/` —
- `New_Moon.svg`
- `Waxing_Crescennt.svg` *(sic)*
- `First_Quarter.svg`
- `Waxing_Gibbous.svg`
- `Full_Moon.svg`
- `Waning_Gibbous.svg`
- `Third_Quarter.svg`
- `Waning_Crescennt.svg` *(sic)*
- `Moon_Background.svg` — horizontally-barred backdrop the phase glyph sits on (matches the zodiac symbol block treatment).

## Zodiac (`Zodiac signs` frame `15:4297`)

Symbol + Stars pair for each of the 12 signs. Use `Stars/<Sign>` for the constellation layer and `Symbol/<Sign>` for the glyph.

**Designer's notes (zodiac)** — from `docs/CC Design Specifications.pdf` §3:
- 12 signs, each with a constellation line-drawing (`Stars/<Sign>`) and a horizontally-barred symbol block (`Symbol/<Sign>`).
- The symbol's horizontal bars are what the hologram zodiac layer uses as its "screen" — the hologram translation gives the symbol an animated scan-line look.
- Cyrillic-folder quirk: `design-assets/Zodiac/Сonstellations/` starts with Cyrillic С (not Latin C). Copied into a normalized `Zodiac.xcassets` at build time so the leak doesn't reach the app bundle.

**Exported assets:**
- **Constellations (line drawings)** — `design-assets/Zodiac/Сonstellations/<Sign>.svg` (note the Cyrillic С): `Aquarius.svg`, `Aries.svg`, `Cancer.svg`, `Capricorn.svg`, `Gemini.svg`, `Leo.svg`, `Libra.svg`, `Pisces.svg`, `Sagittarius.svg`, `Scorpio.svg`, `Taurus.svg`, `Virgo.svg`.
- **Symbols (barred blocks — "screen" for hologram zodiac)** — `design-assets/Zodiac/Signs/<Sign>.svg`, same 12 names. Plus `design-assets/Zodiac/Signs/Background_Lines.svg` — the shared horizontal-bar backdrop the symbol sits on.

## Source: designer's PDF

The full, illustrated originals for every "Designer's notes" box above live in `docs/CC Design Specifications.pdf` (12 pages, last updated Jan 18, 2021). Open the PDF when a note is ambiguous or when you need the visual reference the designer drew — it shows the Illustrator construction for the rotation guilloche, the full `A/B/I/S` shape set, transfusion at 0% / 50% / 100% opacity, the hologram blend-mode breakdown, and all eight moon phases and twelve zodiac pairs.

Section map (for quick lookup):

| PDF section | Covers | Inlined under | Exported assets on disk |
|---|---|---|---|
| §1.2 Rotation | Background guilloche construction | **Guilloche patterns** | `design-assets/Guilloche/App/Rotation/` |
| §1.3 Blend "Path to" | Letter-to-shape morph | **Guilloche patterns** | `design-assets/Blended/{A,B,C}/…` (per-line, 3 letters) + `design-assets/Guilloche/App/Blend/` (composites) + `design-assets/Blended_Letters.ai` |
| §2 Gradients | 7 time-of-day gradients + Transfusion | **Gradients** | `design-assets/Gradients/*.png` (7) |
| §3 Zodiac signs | 12 constellation + symbol pairs | **Zodiac** | `design-assets/Zodiac/Сonstellations/*.svg` (12) + `design-assets/Zodiac/Signs/*.svg` (12 + `Background_Lines.svg`) |
| §4 Moon phases | 8 phases | **Moon phases** | `design-assets/Moon_Phases/*.svg` (8 + `Moon_Background.svg`) |
| §5 Holograms | Neon base layers + Title/Name, Location, Zodiac stacks | **Holograms** | `design-assets/Holograms/Neon_{1,2,3,4}.{jpg,png}` (4) |
| §5 Photo color models | Photo luminosity/color blend treatments | **Card variants** | User-supplied photos, runtime composite — no designer exports |
| §6 Style guide & UI kit | Maps back to the `Components` Figma page | **Components** (Figma map) | Figma-only for UI chrome; fonts at `design-assets/fonts/*.ttf` |
| §7 App icon | Small filled vs large line-work variants | **App assets** | `CasualContacts/…/Assets.xcassets/AppIcon.appiconset/` + `LaunchLogo.imageset/` |

## Gaps / open questions

- **Dedicated detail screen** (medium / large card fullscreen). Code has `FeatureDetail` with medium + large variants — no matching Figma frame found in `iOS_Project`. May live in `Specification` page (`39:18331`) or may reuse `Cards/Full[_w_Photo]` at full width. Confirm.
- **Permission primers** (location, photos/camera) — no frames found.
- **Delete confirmation / error / toast** — no frames found.
- **About screen** — `D_Context_Menu` has an "About developers" row but no standalone About frame.
- **Hologram Neon base layer not yet wired into Swift views.** `HolographicText.swift`, `HolographicLocation.swift`, and `HolographicZodiac.swift` all blend plain `.white` foregrounds with no iridescent base underneath — so the rainbow sheen the PDF §5 specifies is currently absent. The assets now exist at `design-assets/Holograms/Neon_{1,2,3,4}.{jpg,png}`; next implementation task must place a Neon image as the bottom layer of each holographic object (inside a `.compositingGroup()`), mask it to the glyph, then apply `.blendMode(.lighten)` / `.luminosity` / `.color` per the PDF. Pick the Neon variant per object (Title, Location, Zodiac) — Figma places `Neon/1–4` one-per-object with one spare; confirm the exact mapping against the Figma card frames before wiring. **If a SwiftUI composite can't match the Figma pixels, stop and ask** — a substitute `LinearGradient` or hand-tinted overlay is not acceptable.
