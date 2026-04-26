Read docs/site/DESIGN.md and docs/site/tokens.json first — they're the design spec and tokens. Astro, zero client JS, deploy to Cloudflare Pages.

NOTE: the spec was originally drafted as dark-only; the site supports BOTH light and dark mode now. Default to the visitor's system preference via prefers-color-scheme; no toggle needed for v1. Use the L0–L4 scale for the light theme and D0–D4 for dark — both palettes are defined in tokens.json. Light theme: page bg = #FFFFFF (L0), body text = #141415 (D4). Dark theme: page bg = #141415 (D4), body text = #E9EAF1 (L2). The existing showcase page (linked below) supports both modes — match that behavior.

VOICE — there's an existing showcase page for this project at https://www.therealadammork.com/casual-contacts. Read it for tone. The voice is casual, conversational, problem-honest, and a little reflective. NOT mystical, not moody, not "almanac". The hook is the awkwardness of forgetting names ("you only have one chance"); the payoff is "every field has a visual representation, so no two cards are alike, which makes them easier to remember." Use that framing — generative visuals as memory anchors — over any cosmic/astrological mystique.

You can lift the existing problem statement verbatim for the hero: "Meeting people and having friendly banter is enjoyable until you forget someone's name." That line is canonical.

CREDITS — the footer should credit Concept & Product: Adam Mork, Hridayam Bakshi // Design: Taras Gribanov. Same convention as the showcase page.

DIFFERENCE FROM THE SHOWCASE PAGE — that page is a 2021 portfolio piece on Adam's site. This is the v1 app marketing site (the app actually shipped in 2026). Don't replicate the portfolio chrome. Do match the voice, the problem framing, the "every field is a visual" pitch, AND the dual-mode support.

ASSETS YOU'LL FIND ATTACHED:
- AppIcon.png (1024×1024) — light mode brand mark for favicon, OG card, hero
- AppIcon-Dark.png — dark mode app icon variant; use as the favicon/hero mark when the page is in dark mode
- AppIcon-Tinted.png — iOS 18 tinted variant, generally not needed for web
- LaunchLogo@3x.png — line-work C from the splash screen, optional secondary mark
- C_Circle.svg — VECTOR brand glyph (the guilloche letter C). Prefer this for any scalable use: section dividers, oversized footer watermark, large hero decoration. Set its stroke via currentColor so it inverts cleanly across modes.
- Sunset.png, Night.png, Dusk.png, Midnight.png — painterly time-of-day gradient bitmaps. Sunset is the primary marketing accent (hero CTA) and works in both modes. Use as <img> or background-image; DO NOT replace with CSS linear-gradient — the painterly bitmap texture is part of the brand.
- 4 woff2-able TTFs: Cormorant SC Bold + SemiBold (display + section titles), Cormorant Infant Variable (body), IBM Plex Mono Regular (metadata only). Self-host as woff2.

HARD RULES:
- Painterly gradient PNGs as bitmap backgrounds — never substitute CSS linear-gradient.
- Cormorant SC for display + section titles, Cormorant Infant for body, IBM Plex Mono for metadata only.
- Apple App Store badge must be Apple's official SVG (do not redraw).
- C_Circle.svg is the brand glyph — use as section divider and oversized footer watermark, drawn with currentColor so it works in both themes.
- Total content budget on /: ≤ 250 words.
- LCP ≤ 1.5s, total transfer ≤ 400 KB, zero client JS.
- Respect prefers-reduced-motion AND prefers-color-scheme.
- Footer attribution: "Concept & Product — Adam Mork, Hridayam Bakshi · Design — Taras Gribanov" (em-dash + middle-dot, IBM Plex Mono).
