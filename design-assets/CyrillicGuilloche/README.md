# Cyrillic Guilloche

Workspace for developing Cyrillic blended guilloche assets.

## Folders

- `pipeline/`: source and working files for the generation pipeline. This is where foundation-shape seeds, extracted glyph outlines, and intermediate blend outputs should live while the generator is being tuned.
- `app-ingestion/`: finalized generated SVGs once the pipeline output is visually approved and ready to feed into the app's `SVGToSwift` ingestion flow.

## Layer 0 Glyph Outlines

`pipeline/generate-layer0-cyrillic.swift` extracts uppercase Cyrillic glyph outlines from the bundled `CormorantSC-SemiBold.ttf` font and writes normalized `184 x 160` SVGs to:

- `pipeline/glyph-outlines/layer-0/`

The current layer-0 pass fills each normalized glyph into a single mask, traces only the exterior silhouette, and removes counters and small internal detail contours so overlapping font paths do not survive into the blend source. `Ё` and `Й` intentionally use their base glyphs (`Е` and `И`) for now, excluding dots/breve from the blend source. Those add-ons can be restored later as visible layer-0-only detail.

## Intermediate Blends

`pipeline/generate-blends-cyrillic.swift` resamples each layer-0 outline and the existing Latin `A` layer-16 foundation shapes into compatible closed paths, then writes 17 interpolated layers for each of the three variants:

- `Circle`
- `Polygon`
- `Square`

Outputs are written under `pipeline/intermediate-blends/{codepoint}/{variant}/`. `U042B` is intentionally skipped for now because its multi-part source outline needs separate component handling before blending.

## Seed Shapes

The existing Latin `A` layer-16 assets should be treated as the initial canonical foundation shapes:

- `design-assets/Blended/A/Circle/A_C_16.svg`
- `design-assets/Blended/A/Polygon/A_P_16.svg`
- `design-assets/Blended/A/Square/A_S_16.svg`

Keep experimental outputs in `pipeline/` until they match the existing Illustrator-generated assets closely enough for app ingestion.
