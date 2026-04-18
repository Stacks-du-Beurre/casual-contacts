# Design reference — Figma layer map + designer techniques

Reference data for UI work. The **10 design fidelity directives** (Figma canonical, don't cut corners, reuse primitives, verify visually, etc.) live in `CLAUDE.md` and apply to every session — this doc is the map and the how-to.

- **Figma file:** [Casual Contacts](https://www.figma.com/design/aYjd42Fr66HRCV0vQcJAtS/Casual-Contacts)
- **File key:** `aYjd42Fr66HRCV0vQcJAtS`
- **Figma account:** `hello@therealadammork.com`
- **Access via:** the Figma MCP — `get_design_context`, `get_screenshot`, `get_metadata`.

## Light vs Dark

Every screen has both `L_` (Light) and `D_` (Dark) frames. The app ships dark-first (background `#141415`, Dark/D4 token), so **Dark is primary**; Light is listed in parens. Use the Dark node unless explicitly building a light variant.

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
- Seven backgrounds cover the full day: Dawn, Sunrise, Midday, Sunset, Dusk, Night, Midnight. Each has enough contrast to carry white text directly on it.
- **Transfusion effect** (parallax on gyroscope): stack **two identical gradient layers**. Hold the bottom fully opaque; animate the **top layer's opacity from 0 → 100%** based on the device's gyroscope / attitude. The result reads as a liquid, metallic shift as the phone tilts.
- The reduce-motion adapter (`Packages/Sources/AppFeature/ReducedMotionAdapter.swift`) zeroes the attitude input, which collapses transfusion to a static single-gradient look — matches the PDF's "default" state (top opacity fixed at 50%).

**Exported assets:** `design-assets/Gradients/` — one PNG per time-of-day band: `Dawn.png`, `Sunrise.png`, `Midday.png`, `Sunset.png`, `Dusk.png`, `Night.png`, `Midnight.png`. Used as the bitmap source for transfusion's two stacked layers.

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
- Source SVGs live in `design-assets/Rotation/`. Each character is pre-shaped so its centroid lies at a point that, when rotated around, yields the correct guilloche.
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

## Zodiac (`Zodiac signs` frame `15:4297`)

Symbol + Stars pair for each of the 12 signs. Use `Stars/<Sign>` for the constellation layer and `Symbol/<Sign>` for the glyph.

**Designer's notes (zodiac)** — from `docs/CC Design Specifications.pdf` §3:
- 12 signs, each with a constellation line-drawing (`Stars/<Sign>`) and a horizontally-barred symbol block (`Symbol/<Sign>`).
- The symbol's horizontal bars are what the hologram zodiac layer uses as its "screen" — the hologram translation gives the symbol an animated scan-line look.
- Cyrillic-folder quirk: `design-assets/Zodiac/Сonstellations/` starts with Cyrillic С (not Latin C). Copied into a normalized `Zodiac.xcassets` at build time so the leak doesn't reach the app bundle.

## Source: designer's PDF

The full, illustrated originals for every "Designer's notes" box above live in `docs/CC Design Specifications.pdf` (12 pages, last updated Jan 18, 2021). Open the PDF when a note is ambiguous or when you need the visual reference the designer drew — it shows the Illustrator construction for the rotation guilloche, the full `A/B/I/S` shape set, transfusion at 0% / 50% / 100% opacity, the hologram blend-mode breakdown, and all eight moon phases and twelve zodiac pairs.

Section map (for quick lookup):

| PDF section | Covers | Inlined under |
|---|---|---|
| §1 Alphabetical guilloche patterns | Rotation + Blend tool ("Path to") techniques | **Guilloche patterns** |
| §2 Gradients | Seven time-of-day gradients + Transfusion | **Gradients** |
| §3 Zodiac signs | 12 constellation + symbol pairs | **Zodiac** |
| §4 Moon phases | 8 phases | **Moon phases** |
| §5 Holograms & Photo color models | Title/Name, Location, Zodiac hologram stacks + photo luminosity/color blend | **Holograms**, **Card variants** |
| §6 Style guide & UI kit | Maps back to the `Components` Figma page | **Components** (Figma map) |
| §7 App icon | Small filled vs large line-work variants | **App assets** |

## Gaps / open questions

- **Dedicated detail screen** (medium / large card fullscreen). Code has `FeatureDetail` with medium + large variants — no matching Figma frame found in `iOS_Project`. May live in `Specification` page (`39:18331`) or may reuse `Cards/Full[_w_Photo]` at full width. Confirm.
- **Permission primers** (location, photos/camera) — no frames found.
- **Delete confirmation / error / toast** — no frames found.
- **About screen** — `D_Context_Menu` has an "About developers" row but no standalone About frame.
