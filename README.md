# Casual Contacts

An iOS app for quickly recording the people you meet in passing — at cafés, parties, concerts — where a first name and a small detail is all you really have. Every saved contact becomes a one-of-a-kind visual card derived from the moment it was captured, so the memory sticks.

![Casual Contacts](design-assets/CC%20Showcase/%D0%A1%D0%A1.gif)

## Inspiration

> Meeting people and having friendly banter is enjoyable until you forget someone's name. Usually you only have one chance, and forgetting leads to awkward conversations.

![Light and dark modes](design-assets/CC%20Showcase/Light_%26_Dark_Modes.png)

Additional walkthroughs:

- [App walkthrough](design-assets/CC%20Showcase/CC.mp4)
- [2D overview](design-assets/CC%20Showcase/CC_2D.mp4)
- [Floating action button](design-assets/CC%20Showcase/Floating_action_btn.mp4)

## Remembering a contact

Every field has a visual representation in the UI. There is some randomness, so no two cards will be alike. This makes them unique and relevant to the moment they were saved — which should make them easier to remember.

Examples:

- The first letter of a name influences two line patterns in the background.
- Time of day influences the background's gradient.

![Visual specification](design-assets/CC%20Showcase/Specification.png)

## Contact information

- **Required:** name
- **Optional:** description, zodiac sign
- **Auto-populated:** location, moon phase, time of day, position of the sun

### Card previews

<table>
  <tr>
    <td><img src="design-assets/CC%20Showcase/Small_Cards/Small_Card.png" width="220" alt="Card preview"></td>
    <td><img src="design-assets/CC%20Showcase/Small_Cards/Small_Card_1.png" width="220" alt="Card preview"></td>
    <td><img src="design-assets/CC%20Showcase/Small_Cards/Small_Card_2.png" width="220" alt="Card preview"></td>
    <td><img src="design-assets/CC%20Showcase/Small_Cards/Small_Card_3.png" width="220" alt="Card preview"></td>
  </tr>
  <tr>
    <td><img src="design-assets/CC%20Showcase/Small_Cards/Photo.png" width="220" alt="Photo preview"></td>
    <td><img src="design-assets/CC%20Showcase/Small_Cards/Photo-1.png" width="220" alt="Photo preview"></td>
    <td><img src="design-assets/CC%20Showcase/Small_Cards/Photo-2.png" width="220" alt="Photo preview"></td>
    <td><img src="design-assets/CC%20Showcase/Small_Cards/Photo-3.png" width="220" alt="Photo preview"></td>
  </tr>
</table>

## Technical highlights

- **Swift 6 / SwiftUI** with strict concurrency enabled throughout.
- **Modular Swift Package** — feature modules import only `CoreModels` protocols, `DesignSystem`, and `Visuals`; storage and device services live behind seams the compiler enforces.
- **Persistence** via SwiftData for records and a filesystem-backed photo store, each with an in-memory fake for tests.
- **Ambient capture** — moon phase, time-of-day gradient, and optional location/sun position are derived from `CoreLocation` + `CoreMotion` services at save time.
- **Procedural visuals** — guilloche backgrounds are generated from SVG via a custom `SVGToSwift` tool and composited with zodiac, hologram, and transfusion layers using SwiftUI `Canvas` and blend modes.
- **~125 unit tests** across ~36 suites, plus committed snapshot tests for visual regression on the card renderer.

## Development

The app is a thin `@main` shell over a Swift Package. Feature modules depend only on `CoreModels` protocols, `DesignSystem`, and `Visuals` — SwiftData, CoreLocation, and CoreMotion are kept behind service seams.

### Run tests (host)

```bash
cd Packages
swift test
```

### Run tests (simulator)

```bash
cd Packages
xcodebuild test \
    -scheme CasualContactsPackages-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Build and install the app

```bash
xcodebuild build \
    -scheme CasualContacts \
    -destination 'platform=iOS Simulator,name=iPhone 17'

xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install "iPhone 17" \
    CasualContacts/build/Debug-iphonesimulator/CasualContacts.app
xcrun simctl launch "iPhone 17" com.stacksdubeurre.CasualContacts
```

### Regenerate guilloche Swift files

Required after any change under `Tools/SVGToSwift/` or a new drop of SVGs in `design-assets/Rotation/` or `design-assets/Blended_export/SVG/`:

```bash
./Tools/regenerate-svg.sh
```

## Further reading

- `docs/DESIGN.md` — screen-to-Figma map and designer techniques
- `docs/superpowers/specs/2026-04-17-casual-contacts-design.md` — architecture, data model, visual system
- `docs/CC Design Specifications.pdf` — designer-authored specs for guilloche, holographic blends, photo treatments
