# Handoff: Casual Contacts — Marketing Site

## Overview
A single-page marketing site for **Casual Contacts**, an iOS app for remembering people you barely met. The page introduces the app, explains why it exists, shows a few sample generated cards and product screenshots, answers FAQs, lists credits, and routes visitors to the App Store and the open-source repo.

The visual direction is "field-guide / specimen sheet" — a near-white page with a deep slate foreground, set in **Cormorant** (display + body, with serif small caps used as eyebrows and a sectional numbering system §01–§05) and **IBM Plex Mono** for hairline metadata. The page is intentionally quiet: no gradients on chrome, no rounded-corner cards, no decorative iconography. The painterly card artwork and the framed product screenshots do all the visual work.

## About the Design Files
The files in this bundle are a **design reference** — a working HTML/JSX/CSS prototype that shows exact look, copy, and behavior. They are **not** intended to be shipped as-is.

Your job is to recreate this design **in the target codebase's environment**, using its established patterns and libraries. If the marketing site ships from a static-site framework (Astro, Next.js, Eleventy, plain HTML+Vite, etc.), use that. If no codebase exists yet, **Astro is the recommended choice** — the page is largely static, has no client-side state beyond a `<details>` accordion, and Astro will let you keep the same component structure with near-zero JS at runtime. The current prototype only uses React because it was the fastest way to compose the page in a single file; the production version does not need React.

## Fidelity
**High-fidelity.** Treat the prototype as pixel-spec for color, type, spacing, and copy. Where you have to make judgment calls (e.g. responsive breakpoints below 540px, hover transitions on buttons that don't yet exist), follow the patterns already in `site.css`.

## Page Sections (in source order)

The page is composed of 8 ordered components in `site.jsx`. Each maps cleanly to one section in the rendered page.

### 1. `TopNav`
- Sticky-feeling but not sticky (just sits at top of `<body>`).
- Left: a **logo glyph** (the "C" mark from `assets/LogoLarge.svg`) rendered as a CSS `mask-image` so it tints to `var(--fg-1)` (and inverts in dark mode). Followed by the wordmark "casual contacts" in Cormorant SC, lowercase.
- Right: a meta string `v1.0 · ios` in IBM Plex Mono.
- Padding: 24px 64px (12px 24px below 540px).

### 2. `Hero` (showcase composition, §00 — unlabelled)
The hero is modeled after the proposal cover sheet (`Casual_Contacts.png`), not a typical SaaS hero.

- **Centered brand mark**: the iOS app icon (`assets/AppIcon.png`) rendered at 132×132 with a 22.37% border-radius (Apple squircle ratio). On a dark-mode tile background.
- **Title**: `Casual Contacts` in Cormorant SC Bold, large display size.
- **Sub-eyebrow**: `iOS Application`, 18px, 4px tracked, uppercase.
- **Two-up below the title**:
  - **Left column**: a Noble specimen mockup recreated in DOM. This is a precise reproduction of the "Noble" specimen card from the proposal — guilloche line work, holographic seal, name + meta. See `site.jsx` for the exact JSX.
  - **Right column**: the canonical Casual Contacts card art (`assets/CC_Noble_export.png`) clipped to the hero clipping path (`assets/CC_Hero_Clipping.svg`, a 547×807 box with 62.4px corner radius).
- **Tagline** below the two-up, centered, max 760px:
  > "Casual Contacts, like the Nobles, speaks for itself — just one glance is enough to understand its luxury."
  22px Cormorant SC Bold, 32px line-height, 3.2px tracked, uppercase, color `var(--fg-3)`.
- **Actions row**: the official **App Store badge** (`assets/AppStoreBadge.svg` — the preferred-black US/UK English variant from Apple's marketing guidelines, 092917 dated artwork) at 56px tall, plus three "stamps" (Available / iPhone · iOS 17+, Built / 2025, Source / Open) in IBM Plex Mono.

### 3. `HowItWorks` — §01
A three-step list. Each step has a Roman numeral, a short title, and 2–3 sentences of body copy. Layout: a thin top border, three rows separated by 1px borders, each row a 2-column grid (numeral+title left, body right). Numerals are Cormorant SC Bold at the display scale; titles are 28px; body is Cormorant Infant SemiBold at 17px.

Steps:
1. **Capture** — name and a short note. The app fills in the where and the when on its own (address, time of day, season, moon phase, zodiac).
2. **Generate** — those values seed a card. Guilloche line-work in the shape of the first letter, palette pulled from the time of day, holographic seal, constellation, phase of the moon. No two records look alike.
3. **Recall** — flip through the deck later. The card image surfaces the name before you've read it.

### 4. `Gallery` — §02 "specimens"
Four sample cards in a 4-column grid (2 columns below 880px, 1 below 540px). Each cell is a card image plus a small caption (name, date · time-of-day) in IBM Plex Mono.

Card lineup (mapped from `assets/cards/`):
- `Photo_1.png` — Bernard, aug 25, 2020 · sunset
- `Card_3.png` — Alona, nov 24, 2019 · midday
- `Photo_4.png` — Satori, jun 24, 2019 · midday
- `Card_4.png` — Isaiah, jul 28, 2019 · dusk

**Important**: The card PNGs must render with **no border-radius and no clipping**. They have native edges and any rounding will crop the artwork.

### 5. `Essay` — §03 "why it exists"
The product narrative. Eyebrow "why it exists", H2 "You only get one chance to remember someone's name." Layout: 2-column (160px sidebar with a pull-quote, then the body). Body is 4 paragraphs of Cormorant Infant SemiBold at 17px / 27px line-height, max-width ~640px. The pullquote is 21px italic, color `var(--fg-3)`.

Copy is final — see `site.jsx` for the exact text. Do not paraphrase or shorten.

### 6. `PhoneStrip` — §04 "in the app"
A 3-column CSS grid showing three framed iPhone screenshots from `assets/screens/`:

1. `02-list_framed.png` — caption "Records list" / "every card unique"
2. `06-create-step2_framed.png` — caption "Create flow" / "preview as you type"
3. `03-list-sort-open_framed.png` — caption "Sort & filter" / "by name, date, place"

The PNGs already include device chrome and a transparent-background drop shadow — render them at `width: 100%; max-width: 260px; height: auto;` with no extra frame, no border, no shadow. Captions sit centered beneath each image: a small-caps label (Cormorant SC, 14px, 2px tracked, uppercase) and an italic note (Cormorant Infant Italic, 14px, color `var(--fg-4)`).

The `?v=2` query string in the JSX is just a cache-bust during iteration; it can be dropped at build time.

### 7. `FAQ` — §05
Native `<details>` / `<summary>` accordion. The first item is open by default. 6 questions:

1. Where does my data live?
2. How is the card visual generated?
3. Can I edit a card later?
4. Is there an Android version?
5. Is it open source? — answer renders with a clickable link to `https://github.com/stacks-du-Beurre/casual-contacts` (`target="_blank"`, `rel="noopener noreferrer"`).

`<summary>` styling: 21px Cormorant SC Bold, with a `+` / `−` indicator drawn via `::after` (no chevron SVG). Body is 17px / 27px Cormorant Infant SemiBold, max-width 640px, color `var(--fg-3)`.

### 8. `Colophon` (credits + privacy + secondary App Store badge)
Two-column layout. Left: roles list — **Concept & engineering — Adam Mork** and **Design — Taras Gribanov**. Right: a small "On device. Nowhere else." privacy note with the C glyph, then a second App Store badge.

### 9. `Footer`
- A full-width rule.
- Three columns of small links + meta.
- Fineprint row: `© 2026 casual contacts · all rights reserved` and `concept & engineering — adam mork · design — taras gribanov`.

## Interactions & Behavior
- **TopNav** — no dropdowns, no mobile menu. The wordmark links to `#top`.
- **App Store badges** — link to the App Store listing (placeholder `href="#"` in the prototype). Per Apple's guidelines: do not modify the badge artwork, do not animate it, do not tilt it.
- **Github link** (FAQ #5) — opens in a new tab.
- **FAQ accordion** — uses native `<details>`. The first item has the `open` attribute; the rest are closed. The `+` / `−` indicator transitions via the `[open]` selector — no JS.
- **Tweaks panel** — the prototype includes a Tweaks panel for design iteration. **Do not ship it.** Strip the entire `App` wrapper's tweaks state, the `<TweaksPanel>` JSX, and the `tweaks-panel.jsx` file from the production build.
- **Hover/active** — the App Store badge gets `filter: brightness(1.05)` on hover and `transform: scale(0.985)` on active. Apply the same pattern (subtle, no color shift) to any other interactive element you add.

## State Management
None. Every section is static content. The only client-side behavior is the FAQ accordion (handled by the browser via `<details>`).

## Design Tokens

Source of truth: `colors_and_type.css`. Every token below is already defined there as a CSS custom property — use those properties, do not hard-code values.

### Colors
The system has a 5-step **Light** ramp (L0 → L4, lightest to less-light) and a 5-step **Dark** ramp (D0 → D4, lightest neutral to deepest near-black), plus a small accent palette. The page uses semantic aliases that switch in `prefers-color-scheme: dark`:

| Semantic token   | Light value     | Dark value      | Used for                          |
|------------------|-----------------|-----------------|-----------------------------------|
| `--bg-page`      | `--L0` (#FAFAF7)| `--D4` (#141415)| Page background                   |
| `--bg-surface`   | `--L1`          | `--D3`          | Subtle inset cards (privacy note) |
| `--fg-1`         | `--D4`          | `--L0`          | Primary text                      |
| `--fg-2`         | `--D3`          | `--L1`          | H2, FAQ summary                   |
| `--fg-3`         | `--D2`          | `--L2`          | Body copy, tagline                |
| `--fg-4`         | `--D1`          | `--L3`          | Captions, italic notes            |
| `--fg-5`         | `--D0`          | `--L4`          | Hairline metadata, FAQ `+`        |
| `--border`       | rgba(20,20,21,.08) | rgba(255,255,255,.08) | All hairlines           |
| `--accent`       | (defined in CSS)| (defined in CSS)| Reserved — currently unused on this page |

The page does not use any non-grayscale color. If marketing eventually wants a CTA accent, pull from the design system's accent ramp — do not invent one.

### Typography
Three families, all self-hosted from `fonts/`:
- **Cormorant SC** (Bold, SemiBold) — display, eyebrows, FAQ summary, wordmark.
- **Cormorant Infant** (Variable, SemiBold) — body copy, captions.
- **IBM Plex Mono** (Regular) — metadata, dates, fineprint, stamps.

CSS variables: `--serif-display`, `--serif-body`, `--mono`. Defined in `colors_and_type.css`. `font-feature-settings` for old-style figures and small-caps where applicable is already wired in that file — keep it.

Type scale used on this page (every value is in `site.css`; this is just the inventory):
- Hero title: clamp at the largest end (~80px), Cormorant SC Bold.
- H2: 36px / 44px, Cormorant SC Bold.
- Tagline: 22px / 32px, Cormorant SC Bold, 3.2px tracked, uppercase.
- Step title: 28px, Cormorant SC Bold.
- FAQ summary: 21px / 28px, Cormorant SC Bold.
- Body: 17px / 27px, Cormorant Infant SemiBold, letter-spacing -0.05em.
- Eyebrow / cap-label: 13–14px Cormorant SC Bold, 2–4px tracked, uppercase.
- Mono meta: 11–13px IBM Plex Mono, 0.5–1px tracked.

### Spacing
There's no formal scale in the design system file — the page uses ad-hoc values driven by the type sizes. The convention in `site.css`:
- Section vertical rhythm: 96–128px between sections.
- Container max-width: ~1180px, padded 64px (32px below 880px, 24px below 540px).
- Grid gaps: 32px (default), 24px (tight), 56px (generous, between hero and tagline).

### Border radius
- Hero clipping path: 62.4px (defined by the SVG, do not override).
- App icon tile: 22.37% (Apple squircle ratio).
- Card images: **0px**. Native edges only.
- Phone screenshots: 0px (the framed PNGs include their own corners).

### Shadows
- App icon tile: `0 12px 28px rgba(20,20,21,0.18)` (light), `0 12px 28px rgba(0,0,0,0.55)` (dark).
- That's the only shadow on the page. Card images and phone shots have no CSS shadows.

## Assets

All assets live in `assets/` in the bundle. Provenance:

### From the Casual Contacts design system (project `019dc6be-ff9c-7abe-b4cb-5477a65e3009`)
- `AppIcon.png`, `AppIcon-Dark.png`, `AppIcon-Tinted.png` — the iOS app icon variants.
- `cards/Card_1.png` … `cards/Card_4.png` — the four "card" specimen images (the painterly artwork variant).
- `cards/Photo_1.png` … `cards/Photo_4.png` — the four "photo" specimen images (with portrait photography underneath the gradient).
- `Sunset.png`, `Dusk.png`, `Night.png`, `Midnight.png`, `Dawn.png` — the painterly time-of-day gradients (carried over but currently unused on this page).
- `LaunchLogo.png` (and `@2x`, `@3x`) — splash variants (carried over, unused on the page).
- `C_Circle.svg` — an alternative C-mark (currently unused on the page).

### From the user-supplied uploads
- `LogoSmall.svg`, `LogoLarge.svg` — the canonical logo. **Modified**: `fill="white"` was rewritten to `fill="currentColor"` so the SVG can be tinted via CSS `mask-image` + `background-color`. Keep this rewrite in production.
- `CC_Noble_export.png` — the Casual Contacts hero card export (the painterly Noble card art).
- `CC_Hero_Clipping.svg` — a 547×807 rounded-rectangle path used to clip the hero card.

### From Apple
- `AppStoreBadge.svg` — preferred-black US/UK English variant, 092917 artwork, downloaded directly from `developer.apple.com/app-store/marketing/guidelines/`.
- `AppStoreBadge_white.svg` — the alternative white variant, available for any future dark-background placement (not currently used on the page).

### Product screenshots
- `screens/02-list_framed.png` — records list view, light mode, with iPhone frame baked in.
- `screens/03-list-sort-open_framed.png` — list with sort modal open, light mode, framed.
- `screens/06-create-step2_framed.png` — create flow step 2, light mode, framed.

These are large (~4.5 MB each at 1500×3067). **Run them through an image optimizer before launch** — `oxipng -o6` or `sharp` with a 1200px max width should drop them to <500 KB each without visible loss. Consider also generating WebP/AVIF variants and serving them via `<picture>`.

If marketing wants the strip to honor `prefers-color-scheme`, framed dark-mode variants need to be added to `Screenshots/dark/` first (the originals were only generated in light).

## Files

The bundle's HTML/JSX/CSS sources, in order of importance:

- **`index.html`** — entry point. Imports React 18.3.1 + Babel standalone, then `colors_and_type.css`, `site.css`, `tweaks-panel.jsx`, `site.jsx`. The script tags use pinned versions and SRI integrity hashes; if you keep React in production, keep these pins. If you migrate to Astro/Next/etc., drop these entirely.
- **`site.jsx`** — every page component (`TopNav`, `Hero`, `HowItWorks`, `Gallery`, `Essay`, `PhoneStrip`, `FAQ`, `Colophon`, `Footer`, `App`). Strip the `App` wrapper's tweaks state and `<TweaksPanel>` JSX before shipping.
- **`site.css`** — all page-specific layout and typography. References tokens from `colors_and_type.css`.
- **`colors_and_type.css`** — design system tokens and `@font-face` declarations. Keep this file as-is; it's the canonical source for both this page and the iOS app marketing.
- **`tweaks-panel.jsx`** — design-time control panel. **Do not ship.**
- **`fonts/`** — five self-hosted font files (Cormorant Infant SemiBold + Variable, Cormorant SC Bold + SemiBold, IBM Plex Mono Regular). License-cleared OFL fonts; ship them or load from a hosted CDN.
- **`assets/`** — everything listed in the Assets section above.

## Notes for the implementer

- **No analytics, no cookies, no tracker scripts** are wired in. Marketing may want to add Plausible or similar — keep it lightweight and avoid anything that requires a consent banner.
- **The page is responsive down to ~360px** but has not been tuned for very small screens. Verify on iPhone SE (375px) before launch.
- **The Tweaks panel** in the prototype lets you cycle through alternate hero headlines and toggle the gallery section. None of those toggles need to ship; the canonical content is the default.
- **Headline alternatives** (in `site.jsx` as `HEADLINE_OPTS`) are exploratory — only the canonical one is referenced by the live hero. Keep or drop based on your editorial review.
- The page does **not** include schema.org markup, OpenGraph tags, or a favicon link. Add these in `index.html`'s `<head>` for production.

---

**One-line elevator pitch for Claude Code:**
> Recreate this static marketing page (HTML/JSX prototype in this folder) in our codebase. Keep all copy, all assets, all colors and type exact. Strip the Tweaks panel. Optimize the screenshot PNGs. The page has no dynamic state beyond a native `<details>` accordion.
