# Casual Contacts — Marketing Site Design Spec

A focused, two-page static site for the Casual Contacts iOS app. This document is the design brief consumed by Claude Design / `frontend-design` agents, and the source of truth for site visuals.

- **Pages:** `/` (marketing) · `/privacy`
- **Stack target:** Astro (static, zero-JS by default), deployed to Cloudflare Pages
- **Companion file:** `tokens.json` (W3C DTCG tokens, same folder)
- **Parent app design doc:** `../DESIGN.md` (iOS app — different concerns, but shares brand)
- **Note:** site code will land in a future `site/` folder at the repo root. This document is the design brief, not the build.

> **Note on Figma:** the existing Figma file (`aYjd42Fr66HRCV0vQcJAtS`, "Casual Contacts") covers iOS screens only — there are **no marketing-site frames yet**. This spec extracts the brand essentials (palette, type, gradients, glyph language, app icon) from the iOS design system and prescribes how they should compose into a web marketing context. If marketing frames are added to Figma later, link their node IDs in the **Figma references** table below and update this spec to defer to them.

---

## 1. Brand essence

Casual Contacts is for **remembering people you barely met**. The aesthetic is **moody, painterly, slightly mystical** — sunset gradients, hand-drawn guilloche glyphs, holographic chrome — never corporate, never minimal-tech. The marketing site should feel like a **printed object** (catalog, almanac, art-book endpaper) more than a SaaS landing page.

**Voice:** quiet, observational, second-person. Short sentences. No exclamation marks. No "revolutionize", no "powered by AI".

**Visual mood references** (already in the app):
- Painterly time-of-day gradients (Dawn → Midnight, 7 stops)
- Cormorant SC display type with generous tracking
- IBM Plex Mono for metadata (time stamps, location strings)
- Letter-as-glyph guilloche (the "C" of Casual Contacts as rosette pattern)
- Holographic title treatment (lighten + luminosity blend stack)

---

## 2. Pages & sections

### 2.1 `/` — Marketing (single scroll)

Top → bottom:

| # | Section | Purpose | Key elements |
|---|---|---|---|
| 1 | **Hero** | Identity + App Store CTA above the fold | App wordmark, one-sentence value prop, App Store badge, hero card visual (one of the iOS card mocks layered over a gradient) |
| 2 | **What it is** | One paragraph, one image | 2–3 sentences explaining the "casual contact" problem; hand-drawn arrow or guilloche divider |
| 3 | **How it works** | 3 numbered steps | Step cards: *Meet someone* → *Tap +, type their name* → *The card remembers when, where, what was in the air*. Each step gets a small iOS screenshot or visual abstraction. |
| 4 | **Memory through metadata** | Visual showcase | A grid of 4–6 sample cards demonstrating different time-of-day gradients, zodiac signs, moon phases, guilloche glyphs. This is the section that *sells* the aesthetic. |
| 5 | **Privacy first** | Trust + transparency | One paragraph: data stays on-device, optional iCloud sync, no analytics, no ads. Link to `/privacy`. |
| 6 | **Footer** | Closure | App Store badge (repeat), small copyright, link to privacy, contact email |

**Content length budget:** ≤ 250 words across the whole page (excluding footer fine print). The site sells the *feel* — long copy undermines it.

### 2.2 `/privacy` — Privacy policy

Plain document page. Same brand chrome (header wordmark, footer), but body is long-form prose. Use IBM Plex Mono for the document metadata header (last updated date, version) and Cormorant Infant Semibold for body. Sections expected:

1. What we collect (essentially nothing — local-first)
2. iCloud sync (when enabled, what's synced, who can access it)
3. Location data (used only for the optional "Location & time" card field; never transmitted)
4. Photos (stored locally; never uploaded)
5. Analytics (none)
6. Third parties (none)
7. Children's privacy
8. Contact

Substantive policy text is the user's responsibility — this spec defines only the **chrome and typography**, not the legal content.

---

## 3. Layout & breakpoints

Author against three fluid breakpoints, with desktop as the **canonical** context (most App Store traffic comes from social shares opened on desktop, even for an iOS app).

| Breakpoint | Width | Content max-width | Gutters | Notes |
|---|---|---|---|---|
| Mobile | 320 – 767 | 100vw | 24 px | Single column. Hero card scales to ~280 px wide. |
| Tablet | 768 – 1023 | 720 px | 32 px | Sample-card grid: 2 columns. |
| Desktop | 1024 + | 960 px | 64 px | Sample-card grid: 3 columns. Hero is two-column (copy left, card mock right). |

- **Vertical rhythm:** 8 pt baseline. Section spacing 96 px desktop / 64 px mobile.
- **Page background:** Dark/D4 (`#141415`) — same as the app's primary bg. Never pure black.
- **No sticky header.** Header is part of the hero section and scrolls away.

---

## 4. Visual system

### 4.1 Palette

Two parallel scales lifted directly from the app (`Packages/Sources/DesignSystem/Colors.swift`, Figma node `277:11175`).

| Token | Hex | Use |
|---|---|---|
| `color.dark.D4` | `#141415` | Page background (primary) |
| `color.dark.D3` | `#282A30` | Card / surface bg, footer |
| `color.dark.D2` | `#383B43` | Dividers, muted borders |
| `color.dark.D1` | `#4A4C54` | Disabled, fine print |
| `color.dark.D0` | `#5F6068` | Secondary text on dark |
| `color.light.L0` | `#FFFFFF` | Primary text on dark |
| `color.light.L1` | `#F4F5FA` | Headline text |
| `color.light.L2` | `#E9EAF1` | Body text |
| `color.light.L3` | `#D0D1DA` | Tertiary text, captions |
| `color.light.L4` | `#B0B2BC` | Inactive icon, fine print on dark |

The site is **dark-only** for v1. A light-mode pass can come later if the App Store screenshots need a lighter context — but the app ships dark-first and the site should match.

**Accent:** there is no chromatic accent in the brand — color comes from the time-of-day gradients (§4.4). Buttons use white-on-dark with an outline; CTAs use a gradient fill (Sunset, see §4.4).

### 4.2 Typography

Same three families as the app. Self-host the woff2 files alongside the site (do not link to Google Fonts — privacy + reliability).

| Role | Family | Web weight | Sample size (desktop) |
|---|---|---|---|
| Display headline | `Cormorant SC` | 600 | 64 / 72 |
| Section title | `Cormorant SC` | 700 | 33 / 40 |
| Body | `Cormorant Infant` | 600 | 18 / 27 |
| Body small | `Cormorant Infant` | 600 | 13 / 17 |
| Eyebrow / label | `Cormorant SC` | 700 | 12 / 16 (tracking +2.4) |
| Metadata / mono | `IBM Plex Mono` | 400 | 11 / 16 |

- Tracking: section title `0`, body `-0.05`, body-small `-0.2`, eyebrow `+2.4`.
- Cormorant SC is the "quiet headline" — small caps, generous tracking, never bold-italic.
- Cormorant Infant is *only* for body. Never use it for headlines.
- IBM Plex Mono carries metadata: timestamps, version strings, "since 2026" footer text. Use it sparingly — too much mono breaks the painterly mood.

Font files: pull from `design-assets/fonts/` (the iOS package ships TTFs). For the web, convert each to woff2:
- `CormorantSC-Bold.woff2`
- `CormorantSC-SemiBold.woff2`
- `CormorantInfant-Variable.woff2` (variable axis — supported by all modern browsers)
- `IBMPlexMono-Regular.woff2`

Self-host under `site/public/fonts/`.

### 4.3 Spacing & radii

| Token | Value |
|---|---|
| `space.1` | 4 px |
| `space.2` | 8 px |
| `space.3` | 16 px |
| `space.4` | 24 px |
| `space.5` | 32 px |
| `space.6` | 48 px |
| `space.7` | 64 px |
| `space.8` | 96 px |
| `radius.sm` | 4 px (chips) |
| `radius.md` | 12 px (buttons) |
| `radius.lg` | 24 px (card mocks) |
| `radius.xl` | 32 px (hero card) |

### 4.4 Gradients

The seven painterly time-of-day gradients are the brand's color story. Use them as **decorative section accents** — not full-page washes (the page bg stays Dark/D4).

| Gradient | Source PNG | Marketing use |
|---|---|---|
| Sunrise | `design-assets/Gradients/Sunrise.png` | Step 2 (How it works) accent |
| Dawn | `design-assets/Gradients/Dawn.png` | — |
| Midday | `design-assets/Gradients/Midday.png` | — |
| **Sunset** | `design-assets/Gradients/Sunset.png` | **Hero CTA button**, primary marketing accent |
| Dusk | `design-assets/Gradients/Dusk.png` | Step 3 accent |
| Night | `design-assets/Gradients/Night.png` | Step 1 accent |
| Midnight | `design-assets/Gradients/Midnight.png` | Footer top edge fade |

Gradients are **bitmaps**, not procedural CSS gradients — keep the painterly texture. Use as `<img>` (with `loading="lazy"` for any not above the fold) or as CSS `background-image` referencing the PNG.

### 4.5 Glyphs & guilloche

The 26-letter guilloche set lives at `design-assets/Blended_export/SVG/{A–Z}_{Circle,Square,Polygon}.svg`. For the marketing site, use:

- **`C_Circle.svg`** — the brand glyph. Use as a section divider, a hero decoration, and an oversized footer mark.
- **A small hand-picked set** (e.g. `A`, `B`, `C`, `M`, `N` in Circle variant) — for the "Memory through metadata" sample cards, to suggest the per-letter visual identity.

Render guilloche SVGs at intrinsic size (don't stretch). Stroke is `#E9EAF1` (L2) on dark backgrounds. Treat as decorative only — `aria-hidden="true"`.

### 4.6 App icon & screenshots

| Asset | Source | Use |
|---|---|---|
| App icon (large, line-work C) | `CasualContacts/CasualContacts/Assets.xcassets/AppIcon.appiconset/` (1024×1024 export from Figma `Icon/Large` `388:13592`) | Hero, footer, favicon, OG image |
| Apple App Store badge | [Apple official badge](https://developer.apple.com/app-store/marketing/guidelines/) | All CTAs — use Apple's official SVG, do not redraw |
| iOS screenshots | TBD — capture from simulator (iPhone 17, dark mode) at full-screen | Hero card mock, How-it-works steps, Memory grid |

**Screenshot capture command** (when ready):

```bash
xcrun simctl io booted screenshot site/public/screenshots/<name>@3x.png
```

Capture target screens after the app is in a relevant state — empty list, a few seeded cards (use the debug seeder under Settings), the create flow, the detail view. Crop to device frame using a transparent overlay PNG, or ship raw + style with a CSS-drawn frame.

---

## 5. Components

| Component | Description | Reuse from app? |
|---|---|---|
| `Wordmark` | "casual contacts" in Cormorant SC, lowercase, tracking +2.4. Pairs with the line-work C glyph. | New (web only) |
| `AppStoreButton` | Apple's official SVG badge, sized to `radius.md`. | Standard Apple asset |
| `CTAButton` | Sunset gradient bg, Cormorant SC headline 17, white text, `radius.md`, padding `space.3` x. Used only in hero. | New |
| `Section` | Vertical rhythm wrapper. Margin top/bottom `space.8`. | New |
| `Eyebrow` | `Cormorant SC` 700, 12 px, tracking +2.4, color L4. Goes above each section title. | New |
| `CardMock` | Static visual mock of an app card (gradient bg + guilloche + name). For the memory grid. | Adapt from `CardView` (visually only — no SwiftUI on the web) |
| `StepNumber` | Cormorant SC 33 in a Sunset-gradient-filled circle, white text. | New |
| `Footer` | D3 bg, IBM Plex Mono fine print, large oversized C glyph as background watermark. | New |

---

## 6. Imagery & OG card

- **Open Graph / Twitter card** (`/og.png`): 1200×630. Background = Sunset gradient. Centered: line-work C + wordmark. Tagline below in Cormorant Infant SemiBold L1.
- **Favicon**: derive from the app icon. Provide `favicon.ico` + `apple-touch-icon.png` (180×180) + `icon.svg`.

---

## 7. Motion

The app uses gyroscope-driven transfusion, holographic shifts, and parallax. **The web site does not.** Reasons: no gyroscope on most desktop visitors, motion would feel gimmicky in a marketing context, and Cloudflare Pages is best when the payload stays small.

Allowed motion on the site:
- Scroll-triggered fade-in for sections (≤ 200 ms, `cubic-bezier(0.4, 0, 0.2, 1)`).
- Hover state on CTAs: brightness shift 1.05x, 120 ms.
- Nothing else. Respect `prefers-reduced-motion: reduce` and skip even those.

---

## 8. Accessibility

- Body text contrast ≥ 7:1 on Dark/D4 background (L2 on D4 = 14:1, comfortably AAA).
- All decorative SVG (`Wordmark`'s C glyph, guilloche, gradient bitmaps) marked `aria-hidden="true"` or `role="presentation"`.
- App Store badges are images of the official Apple asset — `alt="Download on the App Store"`.
- Keyboard-focus ring: 2 px solid L0 outline, 2 px offset.
- All headings in source order; one `<h1>` per page (the hero headline on `/`, "Privacy policy" on `/privacy`).

---

## 9. Performance budgets

Targets (mobile 4G, Lighthouse):
- LCP ≤ 1.5 s
- Total transfer ≤ 400 KB (incl. fonts)
- JS payload ≤ 0 KB on `/`, ≤ 0 KB on `/privacy` (Astro default)
- Fonts: subset to Latin + relevant punctuation; preload only the two weights used above the fold (Cormorant SC Bold display, Cormorant Infant SemiBold body).
- Images: AVIF with PNG fallback for the gradient bitmaps; lazy-load anything below the fold.

---

## 10. Figma references

| Asset / token | Figma layer | Node ID |
|---|---|---|
| Color tokens (L0–L4, D0–D4) | `Colors` frame | `277:11175` |
| Typography tokens | `Typography` frame | `277:11865` |
| Time-of-day gradients (7) | `Gradients` frame | `9:116` (children: `343:22` Sunrise, `343:26` Dawn, `10:4` Midday, `10:3` Sunset, `31:4` Dusk, `39:4` Night, `343:30` Midnight) |
| Guilloche letters (Blended composites) | `Guilloche_Patterns` frame | `15:30` |
| App icon (large, line-work) | `Icon/Large` | `388:13592` |
| Card variants (visual reference for `CardMock`) | `Cards/Full`, `Cards/Full_w_Photo` | `6:16`, `39:828` |

When implementing, fetch each via the Figma MCP — `get_design_context` (code + screenshot) for components, `get_screenshot` for the gradient bitmaps and icon. Re-fetch every session: Figma asset URLs expire after 7 days.

---

## 11. Out of scope (v1)

- Light mode
- Animated holograms / transfusion
- Press / FAQ / changelog pages
- Newsletter signup
- Multiple languages

If any of these come in scope, add a section above and update `tokens.json` accordingly.
