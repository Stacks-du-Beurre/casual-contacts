# Guilloche Assets

Canonical production guilloche SVGs live under `App/` and are the only inputs
consumed by `Tools/regenerate-svg.sh`.

```text
App/
  Rotation/
    Latin/
    Cyrillic/
  Blend/
    Latin/
    Cyrillic/
Pipeline/
  Cyrillic/
```

`App/Rotation/*` contains one source SVG per glyph. The Swift app expands each
rotation source into the 72-copy rosette at runtime.

`App/Blend/*` contains one composite SVG per glyph and shape. Latin also keeps
the designer's `*_Preview.svg` variants; Cyrillic currently ships the card
shapes only: `Circle`, `Square`, and `Polygon`.

Run `Tools/package-cyrillic-guilloche.py` after regenerating Cyrillic pipeline
outputs. `Tools/regenerate-svg.sh` calls it automatically before converting
Latin SVGs to Swift and copying Cyrillic SVGs into the Visuals resource bundle
for on-demand parsing.
