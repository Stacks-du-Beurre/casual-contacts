# Plan 2 — Design System & Visuals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `DesignSystem` and `Visuals` modules that render every card variant the app will ever show. Deliverable: SwiftUI previews display accurate cards at every size × attitude × metadata combination, with snapshot tests locking in visual regressions. Does not ship a runnable app — that's Plan 3.

**Architecture:** Two new library modules in the local Swift Package. `DesignSystem` holds design tokens (colors, typography, linear gradients) and shared SwiftUI primitives. `Visuals` composes card layers (gradient → guilloche → photo/blend → moon/zodiac → holograms) and exposes a single `CardView` entry point parameterized by `Record` + `CardSize` + `DeviceAttitude`. A build-time tool (`Tools/SVGToSwift`) converts the designer's `.svg` assets into typed Swift `Path` arrays consumed by the guilloche layers.

**Tech Stack:** SwiftUI blend modes (`.lighten`, `.luminosity`, `.color`), `Canvas`, `LinearGradient`, `Image`. One external dependency: `swift-snapshot-testing` (Point-Free) for visual regression tests. Zero Metal shaders in this plan — native blend modes handle the full design.

**Prereq:** Plan 1 merged to `main`. This plan branches off `main`.

---

## File Structure

```
/Users/adam/Projects/cc/
├── Tools/
│   └── SVGToSwift/
│       ├── Package.swift                           # independent exec package
│       ├── Sources/SVGToSwift/
│       │   ├── main.swift                          # CLI entry
│       │   ├── SVGParser.swift                     # d="..." → PathCommand list
│       │   ├── PathCommand.swift                   # enum of M, L, C, Q, Z, etc.
│       │   └── SwiftEmitter.swift                  # PathCommand list → Swift source
│       └── Tests/SVGToSwiftTests/
│           ├── SVGParserTests.swift
│           └── SwiftEmitterTests.swift
├── Packages/
│   ├── Package.swift                               # add DesignSystem + Visuals + snapshot dep
│   └── Sources/
│       ├── DesignSystem/
│       │   ├── Colors.swift                         # Color.cc.L0…L4, D0…D4
│       │   ├── Typography.swift                     # Font.cc.title / headline / etc.
│       │   ├── Gradients.swift                      # LinearGradient.cc.dawn … midnight
│       │   ├── Components/
│       │   │   └── (reusable SwiftUI primitives, added as needed)
│       │   └── Resources/
│       │       └── Fonts/
│       │           ├── CormorantSC-Bold.ttf
│       │           ├── CormorantSC-SemiBold.ttf
│       │           ├── CormorantInfant-Regular.ttf
│       │           ├── CormorantInfant-SemiBold.ttf
│       │           ├── IBMPlexMono-Regular.ttf
│       │           └── LICENSES/
│       │               ├── CormorantSC-OFL.txt
│       │               ├── CormorantInfant-OFL.txt
│       │               └── IBMPlexMono-OFL.txt
│       └── Visuals/
│           ├── CardView.swift                       # public entry point
│           ├── CardSize.swift
│           ├── Layers/
│           │   ├── GradientLayer.swift              # base + transfusion
│           │   ├── GuillocheRotationLayer.swift     # background sunburst
│           │   ├── GuillocheBlendLayer.swift        # letter→shape deep-dive
│           │   ├── PhotoLayer.swift                 # luminosity blend
│           │   ├── MoonPhaseLayer.swift             # 8 glyphs
│           │   ├── ZodiacLayer.swift                # 12 signs, gyro-translated
│           │   └── CardTextLayer.swift              # composes holograms + static info
│           ├── Holographic/
│           │   ├── HolographicText.swift
│           │   ├── HolographicLocation.swift
│           │   └── HolographicZodiac.swift
│           ├── Guilloche/
│           │   ├── LineDensity.swift                # 15 (Cards) | 7 (Recommended)
│           │   └── Generated/                       # gitignored, rebuilt by SVGToSwift
│           │       ├── Rotation_A.swift
│           │       ├── Rotation_B.swift
│           │       ├── ...
│           │       ├── Blend_A_Circle.swift
│           │       └── ...
│           └── Resources/
│               ├── Moon/
│               │   ├── new_moon.svg
│               │   └── ...
│               └── Zodiac/
│                   ├── aries.svg
│                   └── ...
```

**Module dependency additions:**

```
DesignSystem  depends on: SwiftUI
Visuals       depends on: CoreModels, DesignSystem, SwiftUI
VisualsTests  depends on: Visuals, DesignSystem, CoreModels, swift-snapshot-testing
```

`DesignSystem` does NOT depend on `CoreModels` — it's purely visual primitives. `Visuals` is the layer that knows about `Record` and derives `VisualAccoutrements`.

---

## Task 1: Add `swift-snapshot-testing` dependency + DesignSystem target scaffold

**Files:**
- Modify: `Packages/Package.swift`
- Create (empty): `Packages/Sources/DesignSystem/` and `Packages/Tests/DesignSystemTests/`

- [ ] **Step 1: Update `Packages/Package.swift`**

Add to the top-level `dependencies:` (add the key if absent):
```swift
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")
    ],
```

Add to `products`:
```swift
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
```

Add to `targets`:
```swift
        .target(
            name: "DesignSystem",
            path: "Sources/DesignSystem"
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem"],
            path: "Tests/DesignSystemTests"
        ),
```

Full expected `Package.swift` after edits:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CasualContactsPackages",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "CoreModels", targets: ["CoreModels"]),
        .library(name: "Storage", targets: ["Storage"]),
        .library(name: "StorageTestSupport", targets: ["StorageTestSupport"]),
        .library(name: "Services", targets: ["Services"]),
        .library(name: "ServicesTestSupport", targets: ["ServicesTestSupport"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")
    ],
    targets: [
        .target(name: "CoreModels", path: "Sources/CoreModels"),
        .testTarget(name: "CoreModelsTests", dependencies: ["CoreModels"], path: "Tests/CoreModelsTests"),
        .target(name: "Storage", dependencies: ["CoreModels"], path: "Sources/Storage"),
        .testTarget(name: "StorageTests", dependencies: ["Storage", "CoreModels"], path: "Tests/StorageTests"),
        .target(name: "StorageTestSupport", dependencies: ["CoreModels"], path: "Sources/StorageTestSupport"),
        .testTarget(name: "StorageTestSupportTests", dependencies: ["StorageTestSupport", "CoreModels"], path: "Tests/StorageTestSupportTests"),
        .target(name: "Services", dependencies: ["CoreModels"], path: "Sources/Services"),
        .testTarget(name: "ServicesTests", dependencies: ["Services", "CoreModels"], path: "Tests/ServicesTests"),
        .target(name: "ServicesTestSupport", dependencies: ["CoreModels"], path: "Sources/ServicesTestSupport"),
        .testTarget(name: "ServicesTestSupportTests", dependencies: ["ServicesTestSupport", "CoreModels"], path: "Tests/ServicesTestSupportTests"),
        .target(name: "DesignSystem", path: "Sources/DesignSystem"),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"], path: "Tests/DesignSystemTests")
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 2: Create placeholder file so the target isn't empty**

Create `Packages/Sources/DesignSystem/DesignSystem.swift`:
```swift
import SwiftUI

/// Umbrella namespace for design tokens (colors, typography, gradients) and reusable primitives.
public enum CCDesign {}
```

The `CCDesign` namespace (short for Casual Contacts Design) gives us a prefix for `CCDesign.Colors`, `CCDesign.Gradients`, etc. without polluting `Color` / `Font` global extensions (some projects prefer `.cc.` shortcuts — we use a nested enum for discoverability and to avoid surprising the autocomplete list).

- [ ] **Step 3: Create placeholder test**

`Packages/Tests/DesignSystemTests/DesignSystemTests.swift`:
```swift
import Testing
@testable import DesignSystem

@Suite struct DesignSystemSmokeTests {
    @Test func namespaceIsAccessible() {
        // Compilation test — if CCDesign resolves, DesignSystem module imports cleanly.
        _ = CCDesign.self
    }
}
```

- [ ] **Step 4: Build + test**

Run: `cd /Users/adam/Projects/cc/Packages && swift build && swift test`
Expected: `Build complete!`, all previous tests still pass (76), + 1 new test = 77 total.

- [ ] **Step 5: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/
git commit -m "$(cat <<'EOF'
feat(design-system): add DesignSystem module scaffold + snapshot-testing dep

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: DesignSystem Colors

**Files:**
- Create: `Packages/Sources/DesignSystem/Colors.swift`
- Create: `Packages/Tests/DesignSystemTests/ColorsTests.swift`

Ten colors per the design spec's Components page, **exact values extracted from Figma** (node `277:11175` via MCP):

| Token | Hex | Token | Hex |
|---|---|---|---|
| L0 | `#FFFFFF` (pure white) | D0 | `#5F6068` |
| L1 | `#F4F5FA` | D1 | `#4A4C54` |
| L2 | `#E9EAF1` | D2 | `#383B43` |
| L3 | `#D0D1DA` | D3 | `#282A30` |
| L4 | `#B0B2BC` | D4 | `#141415` (darkest ink) |

Note the direction: `L0` is lightest (pure white), `L4` is the darkest light-palette tone; `D0` is the lightest dark-palette tone, `D4` is the darkest. This matches Figma's L→darker-numbered, D→darker-numbered convention.

- [ ] **Step 1: Write failing tests**

`Packages/Tests/DesignSystemTests/ColorsTests.swift`:
```swift
import Testing
import SwiftUI
@testable import DesignSystem

@Suite struct ColorsTests {

    @Test func lightPaletteHasFiveTones() {
        let palette = CCDesign.Colors.light
        #expect(palette.count == 5)
    }

    @Test func darkPaletteHasFiveTones() {
        let palette = CCDesign.Colors.dark
        #expect(palette.count == 5)
    }

    @Test func lightPaletteGoesLightestToDarkest() {
        // L0 is pure white, L4 is darkest light-palette tone. Verified via Figma node 277:11175.
        let palette = CCDesign.Colors.light
        #expect(palette[0] != palette[4])
    }

    @Test func individualAccessors() {
        // Accessible by name.
        _ = CCDesign.Colors.L0
        _ = CCDesign.Colors.L1
        _ = CCDesign.Colors.L2
        _ = CCDesign.Colors.L3
        _ = CCDesign.Colors.L4
        _ = CCDesign.Colors.D0
        _ = CCDesign.Colors.D1
        _ = CCDesign.Colors.D2
        _ = CCDesign.Colors.D3
        _ = CCDesign.Colors.D4
    }
}
```

- [ ] **Step 2: Implement**

`Packages/Sources/DesignSystem/Colors.swift`:
```swift
import SwiftUI

public extension CCDesign {
    enum Colors {
        // Light palette — L0 lightest (pure white) → L4 darkest. Extracted from Figma node 277:11175.
        public static let L0 = Color(red: 1.00, green: 1.00, blue: 1.00)   // #FFFFFF
        public static let L1 = Color(red: 0.957, green: 0.961, blue: 0.980) // #F4F5FA
        public static let L2 = Color(red: 0.914, green: 0.918, blue: 0.945) // #E9EAF1
        public static let L3 = Color(red: 0.816, green: 0.820, blue: 0.855) // #D0D1DA
        public static let L4 = Color(red: 0.690, green: 0.698, blue: 0.737) // #B0B2BC

        // Dark palette — D0 lightest dark → D4 darkest. Extracted from Figma node 277:11175.
        public static let D0 = Color(red: 0.373, green: 0.376, blue: 0.408) // #5F6068
        public static let D1 = Color(red: 0.290, green: 0.298, blue: 0.329) // #4A4C54
        public static let D2 = Color(red: 0.220, green: 0.231, blue: 0.263) // #383B43
        public static let D3 = Color(red: 0.157, green: 0.165, blue: 0.188) // #282A30
        public static let D4 = Color(red: 0.078, green: 0.078, blue: 0.082) // #141415

        public static var light: [Color] { [L0, L1, L2, L3, L4] }
        public static var dark: [Color] { [D0, D1, D2, D3, D4] }
    }
}
```

- [ ] **Step 3: Verify**

`cd /Users/adam/Projects/cc/Packages && swift test --filter ColorsTests` → 4 pass. Full → 81.

- [ ] **Step 4: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/DesignSystem/Colors.swift Packages/Tests/DesignSystemTests/ColorsTests.swift
git commit -m "$(cat <<'EOF'
feat(design-system): add L0–L4 and D0–D4 color palettes

Hex values sourced directly from Figma via MCP (node 277:11175).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: DesignSystem Typography + fonts

**Files:**
- Create: `Packages/Sources/DesignSystem/Typography.swift`
- Create: `Packages/Sources/DesignSystem/Resources/Fonts/` directory structure
- Create: `Packages/Tests/DesignSystemTests/TypographyTests.swift`
- Modify: `Packages/Package.swift` (DesignSystem target needs `resources:` for fonts)

**Font files:** already staged in the repo at `/Users/adam/Projects/cc/design-assets/fonts/` (downloaded from Google Fonts during planning). This task copies them into the package resources.

Files available in `design-assets/fonts/`:
- `CormorantSC-Bold.ttf`
- `CormorantSC-SemiBold.ttf`
- `CormorantInfant-Variable.ttf` (variable font, covers Regular 400 + SemiBold 600 via `.fontWeight()` modifier)
- `IBMPlexMono-Regular.ttf`
- `LICENSES/OFL-CormorantSC.txt`
- `LICENSES/OFL-CormorantInfant.txt`
- `LICENSES/OFL-IBMPlexMono.txt`

**Note on Cormorant Infant:** Google Fonts ships this family as a single variable-axis font file. To get different weights we set `.fontWeight(.semibold)` on SwiftUI `Text` views after applying the base `Font.custom(...)`. The PostScript font name is `CormorantInfant` (no weight suffix).

- [ ] **Step 1: Copy fonts into package resources**

```bash
mkdir -p /Users/adam/Projects/cc/Packages/Sources/DesignSystem/Resources/Fonts/LICENSES
cp /Users/adam/Projects/cc/design-assets/fonts/*.ttf \
   /Users/adam/Projects/cc/Packages/Sources/DesignSystem/Resources/Fonts/
cp /Users/adam/Projects/cc/design-assets/fonts/LICENSES/*.txt \
   /Users/adam/Projects/cc/Packages/Sources/DesignSystem/Resources/Fonts/LICENSES/
ls /Users/adam/Projects/cc/Packages/Sources/DesignSystem/Resources/Fonts/
```

Expected: 4 `.ttf` files + a `LICENSES/` folder with 3 `.txt` files.

- [ ] **Step 2: Update Package.swift**

Update the `DesignSystem` target declaration to include resources:
```swift
        .target(
            name: "DesignSystem",
            path: "Sources/DesignSystem",
            resources: [.process("Resources")]
        ),
```

- [ ] **Step 3: Write failing typography tests**

`Packages/Tests/DesignSystemTests/TypographyTests.swift`:
```swift
import Testing
import SwiftUI
@testable import DesignSystem

@Suite struct TypographyTests {

    @Test func titleFontHasExpectedName() {
        // Swift doesn't expose Font's underlying name cleanly, so we test via description.
        // At minimum, the API surface must exist.
        let font = CCDesign.Typography.title
        #expect(String(describing: font).contains("Cormorant") || String(describing: font).contains("33"))
    }

    @Test func allTypeStylesAreAccessible() {
        _ = CCDesign.Typography.title
        _ = CCDesign.Typography.headline
        _ = CCDesign.Typography.description
        _ = CCDesign.Typography.descriptionSmall
        _ = CCDesign.Typography.caption1
        _ = CCDesign.Typography.caption2
    }

    @Test func fontNamesAreRegisteredBundleResources() {
        // Smoke: font files are in the bundle.
        // Actual font registration happens at app launch via CTFontManager (hooked up in AppFeature in Plan 3).
        let bundle = Bundle.module
        #expect(bundle.url(forResource: "CormorantSC-Bold", withExtension: "ttf") != nil)
        #expect(bundle.url(forResource: "CormorantSC-SemiBold", withExtension: "ttf") != nil)
        #expect(bundle.url(forResource: "CormorantInfant-Variable", withExtension: "ttf") != nil)
        #expect(bundle.url(forResource: "IBMPlexMono-Regular", withExtension: "ttf") != nil)
    }
}
```

- [ ] **Step 4: Implement Typography**

Per design spec §10 (style guide + Components page) and §5.1 of the actual spec doc:

| Style | Family | Weight | Size/Line | Tracking | Case |
|---|---|---|---|---|---|
| Title | Cormorant SC SemiBold | 600 | 33/33 | 0 | — |
| Headline | Cormorant SC Bold | 700 | 16/20 | 2.4 | UPPER |
| Description | Cormorant Infant SemiBold | 600 | 18/27 | -0.05 | — |
| DescriptionSmall | Cormorant Infant Regular | 400 | 13/17 | -0.2 | — |
| Caption1 | Cormorant SC Bold | 700 | 12/12 | 0.2 | UPPER |
| Caption2 | IBM Plex Mono Regular | 400 | 11/12 | 0 | — |

`Packages/Sources/DesignSystem/Typography.swift`:
```swift
import SwiftUI

public extension CCDesign {
    enum Typography {

        // Sizes respect Dynamic Type when used with `.font(...)` modifier. Values are base sizes.
        public static let title = Font.custom("CormorantSC-SemiBold", size: 33, relativeTo: .largeTitle)
        public static let headline = Font.custom("CormorantSC-Bold", size: 16, relativeTo: .headline)
        // CormorantInfant is a variable font — apply .fontWeight(.semibold) on Text for SemiBold.
        public static let description = Font.custom("CormorantInfant", size: 18, relativeTo: .body)
        public static let descriptionSmall = Font.custom("CormorantInfant", size: 13, relativeTo: .footnote)
        public static let caption1 = Font.custom("CormorantSC-Bold", size: 12, relativeTo: .caption)
        public static let caption2 = Font.custom("IBMPlexMono-Regular", size: 11, relativeTo: .caption2)

        /// Letter-spacing (tracking) per design spec. Apply via `.tracking(...)` on Text.
        public enum Tracking {
            public static let title: CGFloat = 0
            public static let headline: CGFloat = 2.4
            public static let description: CGFloat = -0.05
            public static let descriptionSmall: CGFloat = -0.2
            public static let caption1: CGFloat = 0.2
            public static let caption2: CGFloat = 0
        }

        /// Line heights per design spec. Apply via `.lineSpacing(...)` where relevant.
        public enum LineHeight {
            public static let title: CGFloat = 33
            public static let headline: CGFloat = 20
            public static let description: CGFloat = 27
            public static let descriptionSmall: CGFloat = 17
            public static let caption1: CGFloat = 12
            public static let caption2: CGFloat = 12
        }
    }
}
```

- [ ] **Step 5: Verify**

`cd /Users/adam/Projects/cc/Packages && swift test --filter TypographyTests` → 3 pass. Full → 84.

If `fontNamesAreRegisteredBundleResources` fails, the fonts aren't copying into `Bundle.module`. Verify:
- Files are at `Packages/Sources/DesignSystem/Resources/Fonts/*.ttf`
- Package.swift has `resources: [.process("Resources")]` on the DesignSystem target
- File names exactly match (case-sensitive)

- [ ] **Step 6: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/
git commit -m "$(cat <<'EOF'
feat(design-system): add typography scale + bundled fonts

Cormorant SC, Cormorant Infant, IBM Plex Mono shipped as OFL-licensed
resources. Six type styles mapped to Dynamic Type text-style anchors so
body/caption scales respect user-adjusted sizing.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: DesignSystem Gradients

**Files:**
- Create: `Packages/Sources/DesignSystem/Gradients.swift`
- Create: `Packages/Tests/DesignSystemTests/GradientsTests.swift`

Seven linear-gradient definitions — one per `TimeOfDay`. Figma stores these as flattened PNGs (verified via MCP on nodes 9:116, 10:3, etc.), so the canonical stops live in `design-assets/Gradients/*.png`. The values below were sampled at TL / Center / BR with ImageMagick and are the **authoritative** 3-stop approximations for the SwiftUI `LinearGradient`:

| Gradient | TL (start) | C (mid) | BR (end) |
|---|---|---|---|
| Dawn | `#98B5C7` | `#959495` | `#ECC8BC` |
| Sunrise | `#47A9A2` | `#58AAA0` | `#FDECE2` |
| Midday | `#7CC6D5` | `#61A1BB` | `#85CBB2` |
| Sunset | `#D3D9E0` | `#8A839A` | `#A48D9F` |
| Dusk | `#889095` | `#3D4448` | `#FAE0D2` |
| Night | `#5B637E` | `#394164` | `#F2F1F7` |
| Midnight | `#4F4F65` | `#1E202C` | `#ABAFB2` |

Note: several gradients have a lighter "highlight" in the BR corner (especially Dusk, Night, Sunrise). That's a baked-in sheen effect from the designer's originals. SwiftUI `LinearGradient` with diagonal direction approximates the overall feel well; the sheen is slightly flatter than the PNG but still legible.

- [ ] **Step 1: Failing tests**

`Packages/Tests/DesignSystemTests/GradientsTests.swift`:
```swift
import Testing
import SwiftUI
import CoreModels   // for TimeOfDay
@testable import DesignSystem

@Suite struct GradientsTests {

    @Test func everyTimeOfDayHasAGradient() {
        for timeOfDay in TimeOfDay.allCases {
            _ = CCDesign.Gradients.base(for: timeOfDay)
            _ = CCDesign.Gradients.transfusion(for: timeOfDay)
        }
    }

    @Test func baseAndTransfusionAreBothLinearGradients() {
        // API surface check — the return type should be SwiftUI.LinearGradient.
        let base: LinearGradient = CCDesign.Gradients.base(for: .sunset)
        let top: LinearGradient = CCDesign.Gradients.transfusion(for: .sunset)
        _ = base
        _ = top
    }
}
```

Note: we intentionally can't assert on color values of a `LinearGradient` — SwiftUI doesn't expose the stops. Snapshot tests (Task 16) will catch regressions visually.

**Wait — `DesignSystemTests` currently doesn't import `CoreModels`.** We need to update Package.swift first.

- [ ] **Step 2: Update Package.swift for DesignSystemTests dep**

In `Packages/Package.swift`, change the `DesignSystemTests` test target to depend on `CoreModels` as well:

```swift
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem", "CoreModels"],
            path: "Tests/DesignSystemTests"
        ),
```

(Sources of `DesignSystem` itself still do NOT depend on `CoreModels` — only the tests do, because they need `TimeOfDay` for iteration.)

Actually — reconsider. `CCDesign.Gradients.base(for: TimeOfDay)` takes a `TimeOfDay` as a parameter, which means `DesignSystem` (the production target) must import `CoreModels` to type the function. That breaks our "DesignSystem is purely visual primitives" rule.

**Decision:** Gradients will live in the `Visuals` module, NOT `DesignSystem`, so DesignSystem stays free of `CoreModels` coupling. `Visuals` imports both `CoreModels` and `DesignSystem`, and its `GradientLayer` view does the `TimeOfDay → LinearGradient` mapping internally.

**Revised Task 4:** move gradient constants to `Visuals`, defer to Task 8. Close out Task 4 with only the raw gradient factory helper staying in DesignSystem (keyed by name, not TimeOfDay).

- [ ] **Step 1 (revised): Write failing tests**

`Packages/Tests/DesignSystemTests/GradientsTests.swift`:
```swift
import Testing
import SwiftUI
@testable import DesignSystem

@Suite struct GradientsTests {

    @Test func namedGradientsExist() {
        _ = CCDesign.Gradients.dawn
        _ = CCDesign.Gradients.sunrise
        _ = CCDesign.Gradients.midday
        _ = CCDesign.Gradients.sunset
        _ = CCDesign.Gradients.dusk
        _ = CCDesign.Gradients.night
        _ = CCDesign.Gradients.midnight
    }

    @Test func allIsSevenGradients() {
        #expect(CCDesign.Gradients.all.count == 7)
    }
}
```

- [ ] **Step 2 (revised): Implement**

`Packages/Sources/DesignSystem/Gradients.swift`:
```swift
import SwiftUI

public extension CCDesign {
    enum Gradients {

        // All stops sampled from design-assets/Gradients/*.png (see plan Task 4 table).
        // Stops are TL → center → BR; SwiftUI interpolates linearly along .topLeading→.bottomTrailing.

        public static let dawn = LinearGradient(
            colors: [Color(red: 0.596, green: 0.710, blue: 0.780),   // #98B5C7
                     Color(red: 0.584, green: 0.580, blue: 0.584),   // #959495
                     Color(red: 0.925, green: 0.784, blue: 0.737)],  // #ECC8BC
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static let sunrise = LinearGradient(
            colors: [Color(red: 0.278, green: 0.663, blue: 0.635),   // #47A9A2
                     Color(red: 0.345, green: 0.667, blue: 0.627),   // #58AAA0
                     Color(red: 0.992, green: 0.925, blue: 0.886)],  // #FDECE2
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static let midday = LinearGradient(
            colors: [Color(red: 0.486, green: 0.776, blue: 0.835),   // #7CC6D5
                     Color(red: 0.380, green: 0.631, blue: 0.733),   // #61A1BB
                     Color(red: 0.522, green: 0.796, blue: 0.698)],  // #85CBB2
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static let sunset = LinearGradient(
            colors: [Color(red: 0.827, green: 0.851, blue: 0.878),   // #D3D9E0
                     Color(red: 0.541, green: 0.514, blue: 0.604),   // #8A839A
                     Color(red: 0.643, green: 0.553, blue: 0.624)],  // #A48D9F
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static let dusk = LinearGradient(
            colors: [Color(red: 0.533, green: 0.565, blue: 0.584),   // #889095
                     Color(red: 0.239, green: 0.267, blue: 0.282),   // #3D4448
                     Color(red: 0.980, green: 0.878, blue: 0.824)],  // #FAE0D2
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static let night = LinearGradient(
            colors: [Color(red: 0.357, green: 0.388, blue: 0.494),   // #5B637E
                     Color(red: 0.224, green: 0.255, blue: 0.392),   // #394164
                     Color(red: 0.949, green: 0.945, blue: 0.969)],  // #F2F1F7
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static let midnight = LinearGradient(
            colors: [Color(red: 0.310, green: 0.310, blue: 0.396),   // #4F4F65
                     Color(red: 0.118, green: 0.125, blue: 0.173),   // #1E202C
                     Color(red: 0.671, green: 0.686, blue: 0.698)],  // #ABAFB2
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        public static var all: [LinearGradient] {
            [dawn, sunrise, midday, sunset, dusk, night, midnight]
        }
    }
}
```

- [ ] **Step 3: Verify**

`cd /Users/adam/Projects/cc/Packages && swift test --filter GradientsTests` → 2 pass. Full → 86.

- [ ] **Step 4: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/DesignSystem/Gradients.swift Packages/Tests/DesignSystemTests/GradientsTests.swift
git commit -m "$(cat <<'EOF'
feat(design-system): add seven time-of-day LinearGradients

Three-stop approximations sampled from design-assets/Gradients/*.png
(the designer's flattened PNGs — Figma stores them as raster, not
gradient paints, verified via MCP).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Build-time SVG → Swift tool (scaffold + parser)

**Files:**
- Create: `/Users/adam/Projects/cc/Tools/SVGToSwift/Package.swift`
- Create: `/Users/adam/Projects/cc/Tools/SVGToSwift/Sources/SVGToSwift/PathCommand.swift`
- Create: `/Users/adam/Projects/cc/Tools/SVGToSwift/Sources/SVGToSwift/SVGParser.swift`
- Create: `/Users/adam/Projects/cc/Tools/SVGToSwift/Tests/SVGToSwiftTests/SVGParserTests.swift`

`SVGToSwift` is an independent Swift package (not part of `CasualContactsPackages`). It's a CLI that reads `.svg` files and emits Swift source with `Path` constants. This task implements the SVG path-command parser only. CLI entry + emitter come in Task 6.

SVG path-`d` command subset we need to support (based on inspection of the designer's SVGs):
- `M x,y` / `m dx,dy` — moveTo
- `L x,y` / `l dx,dy` — lineTo
- `C x1,y1 x2,y2 x,y` / `c ...` — cubic bezier
- `Q x1,y1 x,y` / `q ...` — quadratic bezier
- `Z` / `z` — closePath
- Numbers may be space-, comma-, or dash-separated

- [ ] **Step 1: Create Tools/SVGToSwift package skeleton**

```bash
mkdir -p /Users/adam/Projects/cc/Tools/SVGToSwift/Sources/SVGToSwift
mkdir -p /Users/adam/Projects/cc/Tools/SVGToSwift/Tests/SVGToSwiftTests
```

`/Users/adam/Projects/cc/Tools/SVGToSwift/Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SVGToSwift",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "svg-to-swift", targets: ["SVGToSwift"])
    ],
    targets: [
        .executableTarget(
            name: "SVGToSwift",
            path: "Sources/SVGToSwift"
        ),
        .testTarget(
            name: "SVGToSwiftTests",
            dependencies: ["SVGToSwift"],
            path: "Tests/SVGToSwiftTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 2: Failing parser tests**

`/Users/adam/Projects/cc/Tools/SVGToSwift/Tests/SVGToSwiftTests/SVGParserTests.swift`:
```swift
import Testing
@testable import SVGToSwift

@Suite struct SVGParserTests {

    @Test func parsesSingleMoveTo() throws {
        let commands = try SVGParser.parse(d: "M10,20")
        #expect(commands == [.moveTo(x: 10, y: 20)])
    }

    @Test func parsesMoveToAndLineTo() throws {
        let commands = try SVGParser.parse(d: "M10,20 L30,40")
        #expect(commands == [.moveTo(x: 10, y: 20), .lineTo(x: 30, y: 40)])
    }

    @Test func parsesCubicBezier() throws {
        let commands = try SVGParser.parse(d: "M0,0 C10,10 20,20 30,30")
        #expect(commands == [
            .moveTo(x: 0, y: 0),
            .cubicBezier(c1x: 10, c1y: 10, c2x: 20, c2y: 20, x: 30, y: 30)
        ])
    }

    @Test func parsesClosePath() throws {
        let commands = try SVGParser.parse(d: "M0,0 L10,0 L10,10 Z")
        #expect(commands.last == .closePath)
    }

    @Test func handlesSpaceOrCommaSeparators() throws {
        let a = try SVGParser.parse(d: "M10,20 L30,40")
        let b = try SVGParser.parse(d: "M10 20 L30 40")
        let c = try SVGParser.parse(d: "M10 20L30 40")
        #expect(a == b)
        #expect(b == c)
    }

    @Test func handlesNegativeNumbersAsSeparators() throws {
        // "-" can act as a separator when preceded by a digit
        let commands = try SVGParser.parse(d: "M10-20L-30-40")
        #expect(commands == [.moveTo(x: 10, y: -20), .lineTo(x: -30, y: -40)])
    }

    @Test func ignoresLeadingAndTrailingWhitespace() throws {
        let commands = try SVGParser.parse(d: "   M10,20   ")
        #expect(commands == [.moveTo(x: 10, y: 20)])
    }

    @Test func throwsOnMalformed() {
        #expect(throws: SVGParserError.self) {
            try SVGParser.parse(d: "Zzz nonsense")
        }
    }
}
```

- [ ] **Step 3: Verify fail**

`cd /Users/adam/Projects/cc/Tools/SVGToSwift && swift test` → FAIL (types missing).

- [ ] **Step 4: Implement PathCommand**

`/Users/adam/Projects/cc/Tools/SVGToSwift/Sources/SVGToSwift/PathCommand.swift`:
```swift
import Foundation

public enum PathCommand: Equatable, Sendable {
    case moveTo(x: Double, y: Double)
    case lineTo(x: Double, y: Double)
    case cubicBezier(c1x: Double, c1y: Double, c2x: Double, c2y: Double, x: Double, y: Double)
    case quadraticBezier(cx: Double, cy: Double, x: Double, y: Double)
    case closePath
}

public enum SVGParserError: Error, Equatable {
    case unexpectedCharacter(Character)
    case unexpectedEnd
    case unknownCommand(Character)
    case malformedNumber(String)
}
```

- [ ] **Step 5: Implement SVGParser**

`/Users/adam/Projects/cc/Tools/SVGToSwift/Sources/SVGToSwift/SVGParser.swift`:
```swift
import Foundation

public enum SVGParser {

    /// Parse the `d` attribute of an SVG `<path>` element into a list of `PathCommand`s.
    /// Supports the subset we need: M, L, C, Q, Z (absolute forms only at this point).
    /// Relative forms (lowercase) and arcs (A) can be added when the assets actually use them.
    public static func parse(d: String) throws -> [PathCommand] {
        var scanner = Scanner(d.trimmingCharacters(in: .whitespacesAndNewlines))
        var commands: [PathCommand] = []

        while !scanner.isAtEnd {
            scanner.skipWhitespaceAndCommas()
            guard let command = scanner.nextChar() else { break }

            switch command {
            case "M":
                let (x, y) = try scanner.readPoint()
                commands.append(.moveTo(x: x, y: y))
            case "L":
                let (x, y) = try scanner.readPoint()
                commands.append(.lineTo(x: x, y: y))
            case "C":
                let (c1x, c1y) = try scanner.readPoint()
                let (c2x, c2y) = try scanner.readPoint()
                let (x, y) = try scanner.readPoint()
                commands.append(.cubicBezier(c1x: c1x, c1y: c1y, c2x: c2x, c2y: c2y, x: x, y: y))
            case "Q":
                let (cx, cy) = try scanner.readPoint()
                let (x, y) = try scanner.readPoint()
                commands.append(.quadraticBezier(cx: cx, cy: cy, x: x, y: y))
            case "Z", "z":
                commands.append(.closePath)
            default:
                throw SVGParserError.unknownCommand(command)
            }
        }

        return commands
    }
}

// MARK: - Scanner

private struct Scanner {
    let characters: [Character]
    var index = 0

    init(_ string: String) {
        self.characters = Array(string)
    }

    var isAtEnd: Bool { index >= characters.count }

    mutating func nextChar() -> Character? {
        guard !isAtEnd else { return nil }
        defer { index += 1 }
        return characters[index]
    }

    func peek() -> Character? {
        isAtEnd ? nil : characters[index]
    }

    mutating func skipWhitespaceAndCommas() {
        while let c = peek(), c.isWhitespace || c == "," {
            index += 1
        }
    }

    mutating func readNumber() throws -> Double {
        skipWhitespaceAndCommas()
        var buffer = ""
        // Optional leading sign
        if let c = peek(), c == "-" || c == "+" {
            buffer.append(c); index += 1
        }
        // Integer part
        while let c = peek(), c.isNumber {
            buffer.append(c); index += 1
        }
        // Decimal part
        if let c = peek(), c == "." {
            buffer.append(c); index += 1
            while let c = peek(), c.isNumber {
                buffer.append(c); index += 1
            }
        }
        guard let value = Double(buffer), !buffer.isEmpty else {
            throw SVGParserError.malformedNumber(buffer)
        }
        return value
    }

    mutating func readPoint() throws -> (x: Double, y: Double) {
        let x = try readNumber()
        // SVG points can be separated by comma, space, or implicit with a leading minus
        skipWhitespaceAndCommas()
        let y = try readNumber()
        return (x, y)
    }
}
```

- [ ] **Step 6: Verify pass**

`cd /Users/adam/Projects/cc/Tools/SVGToSwift && swift test`
Expected: 8 tests pass.

- [ ] **Step 7: Commit**

```bash
cd /Users/adam/Projects/cc
git add Tools/SVGToSwift/
git commit -m "$(cat <<'EOF'
feat(tools): scaffold SVGToSwift parser

A lightweight SVG <path d="..."> parser that extracts moveTo, lineTo,
cubic and quadratic bezier, and closePath commands. Subset is
sufficient for the designer's Rotation and Blend assets. CLI entry
and Swift emitter land in the next task.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: SVG emitter + CLI + Visuals wiring

**Files:**
- Create: `Tools/SVGToSwift/Sources/SVGToSwift/SwiftEmitter.swift`
- Create: `Tools/SVGToSwift/Sources/SVGToSwift/main.swift`
- Create: `Tools/SVGToSwift/Tests/SVGToSwiftTests/SwiftEmitterTests.swift`
- Modify: `Packages/Package.swift` — add `Visuals` target
- Create: `Packages/Sources/Visuals/Guilloche/Generated/` (gitignored)
- Create: `Packages/Sources/Visuals/Guilloche/Generated/.gitkeep` (tracked placeholder)

- [ ] **Step 1: Emitter tests**

`Tools/SVGToSwift/Tests/SVGToSwiftTests/SwiftEmitterTests.swift`:
```swift
import Testing
@testable import SVGToSwift

@Suite struct SwiftEmitterTests {

    @Test func emitsPathConstantForSimpleCommands() {
        let commands: [PathCommand] = [.moveTo(x: 0, y: 0), .lineTo(x: 10, y: 10), .closePath]
        let swift = SwiftEmitter.emit(pathCommands: commands, constantName: "sample")

        #expect(swift.contains("static let sample = Path"))
        #expect(swift.contains("path.move(to: CGPoint(x: 0.0, y: 0.0))"))
        #expect(swift.contains("path.addLine(to: CGPoint(x: 10.0, y: 10.0))"))
        #expect(swift.contains("path.closeSubpath()"))
    }

    @Test func emitsCubicBezier() {
        let commands: [PathCommand] = [
            .moveTo(x: 0, y: 0),
            .cubicBezier(c1x: 10, c1y: 10, c2x: 20, c2y: 20, x: 30, y: 30)
        ]
        let swift = SwiftEmitter.emit(pathCommands: commands, constantName: "curved")

        #expect(swift.contains("path.addCurve(to: CGPoint(x: 30.0, y: 30.0), control1: CGPoint(x: 10.0, y: 10.0), control2: CGPoint(x: 20.0, y: 20.0))"))
    }
}
```

- [ ] **Step 2: Emitter implementation**

`Tools/SVGToSwift/Sources/SVGToSwift/SwiftEmitter.swift`:
```swift
import Foundation

public enum SwiftEmitter {

    /// Emit Swift source that declares a `Path` constant built from the command list.
    /// Caller is responsible for wrapping the output in the right scope (extension, struct, etc.).
    public static func emit(pathCommands: [PathCommand], constantName: String) -> String {
        var body = "    static let \(constantName) = Path { path in\n"
        for command in pathCommands {
            switch command {
            case .moveTo(let x, let y):
                body += "        path.move(to: CGPoint(x: \(x), y: \(y)))\n"
            case .lineTo(let x, let y):
                body += "        path.addLine(to: CGPoint(x: \(x), y: \(y)))\n"
            case .cubicBezier(let c1x, let c1y, let c2x, let c2y, let x, let y):
                body += "        path.addCurve(to: CGPoint(x: \(x), y: \(y)), control1: CGPoint(x: \(c1x), y: \(c1y)), control2: CGPoint(x: \(c2x), y: \(c2y)))\n"
            case .quadraticBezier(let cx, let cy, let x, let y):
                body += "        path.addQuadCurve(to: CGPoint(x: \(x), y: \(y)), control: CGPoint(x: \(cx), y: \(cy)))\n"
            case .closePath:
                body += "        path.closeSubpath()\n"
            }
        }
        body += "    }"
        return body
    }

    /// Emit a full Swift file for multiple named paths inside a namespace.
    public static func emitFile(
        namespace: String,
        paths: [(name: String, commands: [PathCommand])],
        moduleImports: [String] = ["SwiftUI"]
    ) -> String {
        var output = "// Auto-generated by SVGToSwift. Do not edit.\n"
        for module in moduleImports {
            output += "import \(module)\n"
        }
        output += "\npublic extension \(namespace) {\n"
        for (name, commands) in paths {
            output += emit(pathCommands: commands, constantName: name) + "\n\n"
        }
        output += "}\n"
        return output
    }
}
```

- [ ] **Step 3: CLI entry**

`Tools/SVGToSwift/Sources/SVGToSwift/main.swift`:
```swift
import Foundation

// Usage: svg-to-swift <input-dir> <output-dir> <namespace>
// Scans <input-dir> for *.svg, parses each <path d="..."> element, and emits
// one Swift file per SVG into <output-dir>, with all paths under <namespace>.

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    FileHandle.standardError.write(Data("Usage: svg-to-swift <input-dir> <output-dir> <namespace>\n".utf8))
    exit(2)
}

let inputDir = URL(fileURLWithPath: arguments[1])
let outputDir = URL(fileURLWithPath: arguments[2])
let namespace = arguments[3]

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let svgFiles = (try? FileManager.default.contentsOfDirectory(at: inputDir, includingPropertiesForKeys: nil))
    .map { $0.filter { $0.pathExtension.lowercased() == "svg" } } ?? []

for svgFile in svgFiles {
    let name = svgFile.deletingPathExtension().lastPathComponent
    let contents = try String(contentsOf: svgFile, encoding: .utf8)

    // Extract every d="..." attribute. Quick regex — the designer's SVGs use
    // straightforward attribute syntax; if they ever get nested CDATA we'd
    // need a real XML parser.
    let pattern = #"d\s*=\s*"([^"]*)""#
    let regex = try NSRegularExpression(pattern: pattern)
    let matches = regex.matches(in: contents, range: NSRange(contents.startIndex..., in: contents))

    var paths: [(name: String, commands: [PathCommand])] = []
    for (index, match) in matches.enumerated() {
        guard let range = Range(match.range(at: 1), in: contents) else { continue }
        let dString = String(contents[range])
        let commands = try SVGParser.parse(d: dString)
        paths.append((name: "path\(index)", commands: commands))
    }

    let pathsWithContainer: [(name: String, commands: [PathCommand])] = paths
    let swiftSource = SwiftEmitter.emitFile(
        namespace: "\(namespace).\(name)",
        paths: pathsWithContainer
    )

    // Write an enum namespace declaration first, then fill it.
    let fileURL = outputDir.appendingPathComponent("\(name).swift")
    let preamble = "// Auto-generated by SVGToSwift. Do not edit.\nimport SwiftUI\n\npublic enum \(name) {}\n\n"
    let body = SwiftEmitter.emitFile(namespace: "\(namespace).\(name)", paths: pathsWithContainer, moduleImports: [])
    try (preamble + body).write(to: fileURL, atomically: true, encoding: .utf8)

    print("Generated \(fileURL.path) — \(paths.count) paths")
}

print("Done. Processed \(svgFiles.count) SVG files.")
```

- [ ] **Step 4: Verify emitter tests pass**

`cd /Users/adam/Projects/cc/Tools/SVGToSwift && swift test` → 10 pass (8 parser + 2 emitter).

- [ ] **Step 5: Run CLI against the Rotation assets (smoke test)**

```bash
mkdir -p /tmp/svg-swift-smoke
swift run --package-path /Users/adam/Projects/cc/Tools/SVGToSwift svg-to-swift \
    /Users/adam/Projects/cc/design-assets/Rotation \
    /tmp/svg-swift-smoke \
    "CCGuilloche.Rotation"
```

Expected: 26 files generated, one per letter (A_Rotation.swift through Z_Rotation.swift).

Inspect one: `head -20 /tmp/svg-swift-smoke/A_Rotation.swift`

Should look like:
```swift
// Auto-generated by SVGToSwift. Do not edit.
import SwiftUI

public enum A_Rotation {}

public extension CCGuilloche.Rotation.A_Rotation {
    static let path0 = Path { path in
        path.move(to: CGPoint(x: ...
        ...
    }
    ...
}
```

If parse errors occur (unknown commands, malformed d=""), inspect the failing SVG file and extend `SVGParser` to handle the missing command. Report BLOCKED with the specific error rather than skipping affected files.

- [ ] **Step 6: Add Visuals target to Package.swift**

In `Packages/Package.swift`, add to `products`:
```swift
        .library(name: "Visuals", targets: ["Visuals"]),
```

And add to `targets`:
```swift
        .target(
            name: "Visuals",
            dependencies: [
                "CoreModels",
                "DesignSystem"
            ],
            path: "Sources/Visuals"
        ),
        .testTarget(
            name: "VisualsTests",
            dependencies: [
                "Visuals",
                "CoreModels",
                "DesignSystem",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests/VisualsTests"
        ),
```

Create `Packages/Sources/Visuals/Guilloche/Generated/.gitkeep` (empty file, so the generated directory exists but remains empty in source control).

Create `Packages/Sources/Visuals/Visuals.swift`:
```swift
import Foundation

/// Umbrella namespace for the Visuals module.
public enum CCVisuals {}
```

- [ ] **Step 7: Smoke test Visuals target builds**

`cd /Users/adam/Projects/cc/Packages && swift build`
Expected: `Build complete!`.

- [ ] **Step 8: Commit**

```bash
cd /Users/adam/Projects/cc
git add Tools/SVGToSwift/Sources/SVGToSwift/SwiftEmitter.swift \
        Tools/SVGToSwift/Sources/SVGToSwift/main.swift \
        Tools/SVGToSwift/Tests/SVGToSwiftTests/SwiftEmitterTests.swift \
        Packages/Package.swift \
        Packages/Sources/Visuals
git commit -m "$(cat <<'EOF'
feat(tools,visuals): add SVG→Swift CLI + scaffold Visuals module

SVGToSwift CLI scans a directory of .svg files, extracts d="..." path
attributes, and emits a Swift source file per SVG with typed Path
constants. Smoke-tested against design-assets/Rotation producing 26
per-letter files.

Visuals module is scaffolded with CCVisuals namespace; layer views
land in subsequent tasks.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Visuals — GradientLayer with transfusion

**Files:**
- Create: `Packages/Sources/Visuals/Layers/GradientLayer.swift`
- Create: `Packages/Tests/VisualsTests/GradientLayerTests.swift`

A `GradientLayer` stacks two identical gradients and drives the top layer's opacity by `DeviceAttitude.roll`.

- [ ] **Step 1: Failing test**

`Packages/Tests/VisualsTests/GradientLayerTests.swift`:
```swift
import Testing
import SwiftUI
import CoreModels
import DesignSystem
@testable import Visuals

@Suite struct GradientLayerTests {

    @Test func resolvesGradientForEveryTimeOfDay() {
        for timeOfDay in TimeOfDay.allCases {
            _ = GradientLayer.gradient(for: timeOfDay)
        }
    }

    @Test func transfusionOpacityMapsRollToZeroOne() {
        // roll = -1 → opacity 0, roll = 0 → opacity 0.5, roll = +1 → opacity 1
        #expect(GradientLayer.transfusionOpacity(for: DeviceAttitude(pitch: 0, roll: -1)) == 0.0)
        #expect(GradientLayer.transfusionOpacity(for: DeviceAttitude(pitch: 0, roll: 0)) == 0.5)
        #expect(GradientLayer.transfusionOpacity(for: DeviceAttitude(pitch: 0, roll: 1)) == 1.0)
    }

    @Test func transfusionOpacityClampsOutOfRange() {
        // DeviceAttitude is clamped at construction, so anything >1 / <-1 should be clamped before arriving.
        // But the mapping function should also be defensive.
        #expect(GradientLayer.transfusionOpacity(for: DeviceAttitude(pitch: 0, roll: 2).clamped()) == 1.0)
        #expect(GradientLayer.transfusionOpacity(for: DeviceAttitude(pitch: 0, roll: -2).clamped()) == 0.0)
    }
}
```

- [ ] **Step 2: Implement**

`Packages/Sources/Visuals/Layers/GradientLayer.swift`:
```swift
import SwiftUI
import CoreModels
import DesignSystem

public struct GradientLayer: View {

    public let timeOfDay: TimeOfDay
    public let attitude: DeviceAttitude

    public init(timeOfDay: TimeOfDay, attitude: DeviceAttitude) {
        self.timeOfDay = timeOfDay
        self.attitude = attitude
    }

    public var body: some View {
        ZStack {
            Self.gradient(for: timeOfDay)
            Self.gradient(for: timeOfDay)
                .opacity(Self.transfusionOpacity(for: attitude))
        }
    }

    static func gradient(for timeOfDay: TimeOfDay) -> LinearGradient {
        switch timeOfDay {
        case .dawn:     return CCDesign.Gradients.dawn
        case .sunrise:  return CCDesign.Gradients.sunrise
        case .midday:   return CCDesign.Gradients.midday
        case .sunset:   return CCDesign.Gradients.sunset
        case .dusk:     return CCDesign.Gradients.dusk
        case .night:    return CCDesign.Gradients.night
        case .midnight: return CCDesign.Gradients.midnight
        }
    }

    static func transfusionOpacity(for attitude: DeviceAttitude) -> Double {
        (attitude.roll + 1) / 2
    }
}
```

- [ ] **Step 3: Verify pass**

`cd /Users/adam/Projects/cc/Packages && swift test --filter GradientLayerTests` → 3 pass.

- [ ] **Step 4: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/Visuals/Layers/GradientLayer.swift Packages/Tests/VisualsTests/GradientLayerTests.swift
git commit -m "$(cat <<'EOF'
feat(visuals): add GradientLayer with gyroscope-driven transfusion

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Visuals — GuillocheRotationLayer

Renders the per-letter background sunburst from `design-assets/Rotation/<letter>_Rotation.svg`. The path data is emitted by the SVGToSwift tool into `Visuals/Guilloche/Generated/`. Since the Generated folder is gitignored and regenerated per build, Task 8 also adds a SwiftPM plugin invocation (or a lightweight pre-build script alternative) to run the tool.

**Decision for Plan 2:** instead of a SwiftPM plugin (which requires package-wide setup and per-version ceremony), we add a shell script `Tools/regenerate-svg.sh` that the developer runs manually. Plan 3 can upgrade to a full plugin once the pipeline is stable.

**Files:**
- Create: `Tools/regenerate-svg.sh`
- Create: `Packages/Sources/Visuals/Layers/GuillocheRotationLayer.swift`
- Create: `Packages/Tests/VisualsTests/GuillocheRotationLayerTests.swift`

- [ ] **Step 1: Add regenerate script**

`Tools/regenerate-svg.sh`:
```bash
#!/bin/bash
# Regenerates Swift Path constants from design-assets/Rotation/ and
# design-assets/Blended_export/SVG/ into Packages/Sources/Visuals/Guilloche/Generated/.
# Run after updating SVG assets or changing the SVGToSwift tool.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${REPO_ROOT}/Packages/Sources/Visuals/Guilloche/Generated"

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"

swift run --package-path "${REPO_ROOT}/Tools/SVGToSwift" svg-to-swift \
    "${REPO_ROOT}/design-assets/Rotation" \
    "${OUT_DIR}/Rotation" \
    "CCVisuals.Guilloche.Rotation"

swift run --package-path "${REPO_ROOT}/Tools/SVGToSwift" svg-to-swift \
    "${REPO_ROOT}/design-assets/Blended_export/SVG" \
    "${OUT_DIR}/Blend" \
    "CCVisuals.Guilloche.Blend"

echo "Generated $(find "${OUT_DIR}" -name '*.swift' | wc -l) Swift files"
```

```bash
chmod +x /Users/adam/Projects/cc/Tools/regenerate-svg.sh
```

- [ ] **Step 2: Run it once to generate files**

```bash
/Users/adam/Projects/cc/Tools/regenerate-svg.sh
```

Expected: 26 Rotation files + ~104 Blend files generated.

- [ ] **Step 3: Update `.gitignore` scope**

The existing `.gitignore` has `Packages/Sources/Visuals/Guilloche/Generated/`. Confirm still correct (should ignore everything beneath that dir). No change likely needed.

- [ ] **Step 4: Create namespace holder for Guilloche**

`Packages/Sources/Visuals/Guilloche/Guilloche.swift`:
```swift
import SwiftUI

public extension CCVisuals {
    /// Namespace for guilloche pattern assets (Rotation backgrounds, Blend foregrounds).
    /// Concrete paths are emitted into Generated/ by the SVGToSwift tool.
    enum Guilloche {
        public enum Rotation {}
        public enum Blend {}
    }
}
```

- [ ] **Step 5: Implement GuillocheRotationLayer**

Since the Generated/ directory is per-developer, we can't rely on specific symbol names. The layer reads all paths in a `CCVisuals.Guilloche.Rotation.<Letter>_Rotation` enum at runtime via reflection… actually, that's complex. Simpler: the generated code uses a predictable naming convention, and the layer takes the letter as a parameter and looks up the paths via a switch.

But that requires generating a switch. Alternative: we generate all letters into a single dictionary `CCVisuals.Guilloche.Rotation.all: [String: [Path]]`. That's cleaner.

**Update SVGToSwift CLI to support a "dict mode"**: if a `--as-dict` flag is passed, emit a single `public extension <Namespace> { static let all: [String: [Path]] = [...] }` instead of per-file enums. Otherwise keep the current per-file behavior.

This is a medium-size edit to the CLI. Given the plan is getting long, we defer that flexibility to a Plan 2.1 iteration and do a simpler thing here: generate a single lookup file `RotationLookup.swift` after the per-letter files, that imports all of them into a dictionary.

Actually the simplest thing is: the layer takes `[Path]` directly. The caller (from `GuillocheRotationLayer(letter: ..., paths: CCVisuals.Guilloche.Rotation.A_Rotation.paths)`) passes the right set. A Lookup helper can be added later.

For Task 8, implement:

`Packages/Sources/Visuals/Layers/GuillocheRotationLayer.swift`:
```swift
import SwiftUI
import CoreModels
import DesignSystem

public struct GuillocheRotationLayer: View {

    public let paths: [Path]
    public let opacity: Double
    public let tint: Color

    public init(paths: [Path], opacity: Double = 0.2, tint: Color = CCDesign.Colors.L4) {
        self.paths = paths
        self.opacity = opacity
        self.tint = tint
    }

    public var body: some View {
        Canvas { context, size in
            for path in paths {
                context.stroke(path, with: .color(tint.opacity(opacity)), lineWidth: 0.5)
            }
        }
    }
}
```

- [ ] **Step 6: Test**

`Packages/Tests/VisualsTests/GuillocheRotationLayerTests.swift`:
```swift
import Testing
import SwiftUI
@testable import Visuals

@Suite struct GuillocheRotationLayerTests {

    @Test func layerInstantiatesWithEmptyPaths() {
        let layer = GuillocheRotationLayer(paths: [])
        _ = layer.body
    }

    @Test func layerInstantiatesWithSinglePath() {
        let sample = Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: 10, y: 10)) }
        let layer = GuillocheRotationLayer(paths: [sample])
        _ = layer.body
    }
}
```

Verify: `swift test --filter GuillocheRotationLayerTests` → 2 pass.

- [ ] **Step 7: Commit**

```bash
cd /Users/adam/Projects/cc
git add Tools/regenerate-svg.sh \
        Packages/Sources/Visuals/Guilloche/Guilloche.swift \
        Packages/Sources/Visuals/Layers/GuillocheRotationLayer.swift \
        Packages/Tests/VisualsTests/GuillocheRotationLayerTests.swift
git commit -m "$(cat <<'EOF'
feat(visuals): add GuillocheRotationLayer + regenerate-svg script

Tools/regenerate-svg.sh rebuilds Swift Path constants from design-assets
into the gitignored Generated/ directory. GuillocheRotationLayer renders
an array of Paths via Canvas as a subtle low-opacity stroke overlay.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Visuals — GuillocheBlendLayer with parallax deep-dive

**Files:**
- Create: `Packages/Sources/Visuals/Guilloche/LineDensity.swift`
- Create: `Packages/Sources/Visuals/Layers/GuillocheBlendLayer.swift`
- Create: `Packages/Tests/VisualsTests/GuillocheBlendLayerTests.swift`

The "deep dive" effect: 15 paths (or 7 for Recommended) stacked, each offset by `(roll*(i+1), pitch*(i+1))` scaled by a depth constant.

- [ ] **Step 1: LineDensity enum**

`Packages/Sources/Visuals/Guilloche/LineDensity.swift`:
```swift
import Foundation

public extension CCVisuals.Guilloche {
    enum LineDensity: Sendable {
        /// 15 paths — used on Card detail variants (Medium, Large).
        case cards
        /// 7 paths — used on Recommended section cards (Phase 3+).
        case recommended
        /// 7 paths — used on small list cards via the `_Preview.svg` variant.
        case preview

        public var expectedPathCount: Int {
            switch self {
            case .cards: return 15
            case .recommended, .preview: return 7
            }
        }
    }
}
```

- [ ] **Step 2: Tests**

`Packages/Tests/VisualsTests/GuillocheBlendLayerTests.swift`:
```swift
import Testing
import SwiftUI
import CoreModels
@testable import Visuals

@Suite struct GuillocheBlendLayerTests {

    private func makePaths(count: Int) -> [Path] {
        (0..<count).map { _ in
            Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: 10, y: 10)) }
        }
    }

    @Test func flatAttitudeKeepsAllPathsAtSamePosition() {
        // Not easily testable directly through View body — we expose the offset helper.
        for i in 0..<15 {
            let offset = GuillocheBlendLayer.offset(forPathIndex: i, attitude: .zero)
            #expect(offset.width == 0)
            #expect(offset.height == 0)
        }
    }

    @Test func tiltedAttitudeSpreadsPathsByDepth() {
        let attitude = DeviceAttitude(pitch: 0.5, roll: 0.5)
        let innerOffset = GuillocheBlendLayer.offset(forPathIndex: 0, attitude: attitude)
        let outerOffset = GuillocheBlendLayer.offset(forPathIndex: 14, attitude: attitude)

        #expect(abs(outerOffset.width) > abs(innerOffset.width))
        #expect(abs(outerOffset.height) > abs(innerOffset.height))
    }

    @Test func layerInstantiatesAtEveryDensity() {
        let paths15 = makePaths(count: 15)
        let paths7 = makePaths(count: 7)
        _ = GuillocheBlendLayer(paths: paths15, density: .cards, attitude: .zero).body
        _ = GuillocheBlendLayer(paths: paths7, density: .recommended, attitude: .zero).body
        _ = GuillocheBlendLayer(paths: paths7, density: .preview, attitude: .zero).body
    }
}
```

- [ ] **Step 3: Implement**

`Packages/Sources/Visuals/Layers/GuillocheBlendLayer.swift`:
```swift
import SwiftUI
import CoreModels
import DesignSystem

public struct GuillocheBlendLayer: View {

    public let paths: [Path]
    public let density: CCVisuals.Guilloche.LineDensity
    public let attitude: DeviceAttitude
    public let tint: Color

    /// Depth-scaling constant — controls how dramatically the stack fans out on tilt.
    /// 0.5pt per index step gives a subtle parallax without overwhelming the card.
    private static let depthScale: CGFloat = 0.5

    public init(
        paths: [Path],
        density: CCVisuals.Guilloche.LineDensity,
        attitude: DeviceAttitude,
        tint: Color = CCDesign.Colors.L4
    ) {
        self.paths = paths
        self.density = density
        self.attitude = attitude
        self.tint = tint
    }

    public var body: some View {
        ZStack {
            ForEach(paths.indices, id: \.self) { index in
                paths[index]
                    .stroke(tint.opacity(0.8), lineWidth: 0.5)
                    .offset(Self.offset(forPathIndex: index, attitude: attitude))
            }
        }
    }

    static func offset(forPathIndex index: Int, attitude: DeviceAttitude) -> CGSize {
        let depth = CGFloat(index + 1) * depthScale
        return CGSize(
            width: CGFloat(attitude.roll) * depth,
            height: CGFloat(attitude.pitch) * depth
        )
    }
}
```

- [ ] **Step 4: Verify**

`cd /Users/adam/Projects/cc/Packages && swift test --filter GuillocheBlendLayerTests` → 3 pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/Visuals/Guilloche/LineDensity.swift \
        Packages/Sources/Visuals/Layers/GuillocheBlendLayer.swift \
        Packages/Tests/VisualsTests/GuillocheBlendLayerTests.swift
git commit -m "$(cat <<'EOF'
feat(visuals): add GuillocheBlendLayer with depth-scaled parallax

Each stacked path gets an offset proportional to its depth index,
fanning out the 15-line (or 7-line) blend as the device tilts.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Visuals — MoonPhaseLayer

Copy the 8 moon-phase SVGs into the Visuals module as bundle resources and render the correct one for a given `MoonPhase`.

**Files:**
- Copy: `design-assets/Moon_Phases/*.svg` → `Packages/Sources/Visuals/Resources/Moon/`
- Modify: `Packages/Package.swift` (resources for Visuals)
- Create: `Packages/Sources/Visuals/Layers/MoonPhaseLayer.swift`
- Create: `Packages/Tests/VisualsTests/MoonPhaseLayerTests.swift`

- [ ] **Step 1: Copy moon assets**

```bash
mkdir -p /Users/adam/Projects/cc/Packages/Sources/Visuals/Resources/Moon
cp /Users/adam/Projects/cc/design-assets/Moon_Phases/*.svg \
   /Users/adam/Projects/cc/Packages/Sources/Visuals/Resources/Moon/
ls /Users/adam/Projects/cc/Packages/Sources/Visuals/Resources/Moon/
```

Expected: 9 files (8 phases + `Moon_Background.svg`).

- [ ] **Step 2: Update Package.swift**

Add `resources: [.process("Resources")]` to the `Visuals` target:

```swift
        .target(
            name: "Visuals",
            dependencies: [
                "CoreModels",
                "DesignSystem"
            ],
            path: "Sources/Visuals",
            resources: [.process("Resources")]
        ),
```

- [ ] **Step 3: Implement MoonPhaseLayer**

`Packages/Sources/Visuals/Layers/MoonPhaseLayer.swift`:
```swift
import SwiftUI
import CoreModels

public struct MoonPhaseLayer: View {

    public let phase: MoonPhase

    public init(phase: MoonPhase) {
        self.phase = phase
    }

    public var body: some View {
        Image(Self.assetName(for: phase), bundle: .module)
            .resizable()
            .scaledToFit()
    }

    static func assetName(for phase: MoonPhase) -> String {
        switch phase {
        case .newMoon:         return "New_Moon"
        case .waxingCrescent:  return "Waxing_Crescennt"  // preserve source typo
        case .firstQuarter:    return "First_Quarter"
        case .waxingGibbous:   return "Waxing_Gibbous"
        case .fullMoon:        return "Full_Moon"
        case .waningGibbous:   return "Waning_Gibbous"
        case .thirdQuarter:    return "Third_Quarter"
        case .waningCrescent:  return "Waning_Crescennt"  // preserve source typo
        }
    }
}
```

- [ ] **Step 4: Tests**

`Packages/Tests/VisualsTests/MoonPhaseLayerTests.swift`:
```swift
import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import Visuals

@Suite struct MoonPhaseLayerTests {

    @Test func everyPhaseHasABundledAsset() {
        let bundle = Bundle.module
        for phase in MoonPhase.allCases {
            let name = MoonPhaseLayer.assetName(for: phase)
            let url = bundle.url(forResource: name, withExtension: "svg", subdirectory: "Moon")
                ?? bundle.url(forResource: name, withExtension: "svg")
            #expect(url != nil, "Missing moon asset: \(name)")
        }
    }

    @Test func assetNamesArePredictable() {
        #expect(MoonPhaseLayer.assetName(for: .newMoon) == "New_Moon")
        #expect(MoonPhaseLayer.assetName(for: .fullMoon) == "Full_Moon")
    }
}
```

- [ ] **Step 5: Verify**

`cd /Users/adam/Projects/cc/Packages && swift test --filter MoonPhaseLayerTests` → 2 pass.

If the bundle-URL lookup fails: the asset-catalog behavior of `.process("Resources")` may flatten the subdirectory. Check whether `Bundle.module.url(forResource:)` finds the asset without `subdirectory:`. Both forms are tested above as fallbacks.

- [ ] **Step 6: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/Visuals/Resources/Moon \
        Packages/Package.swift \
        Packages/Sources/Visuals/Layers/MoonPhaseLayer.swift \
        Packages/Tests/VisualsTests/MoonPhaseLayerTests.swift
git commit -m "$(cat <<'EOF'
feat(visuals): add MoonPhaseLayer with bundled SVG assets

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Visuals — ZodiacLayer

**Files:**
- Copy: `design-assets/Zodiac/Signs/*.svg` → `Packages/Sources/Visuals/Resources/Zodiac/`
- Copy: `design-assets/Zodiac/Сonstellations/*.svg` → same directory (preserve Cyrillic folder name as context; rename files to ASCII)
- Create: `Packages/Sources/Visuals/Layers/ZodiacLayer.swift`
- Create: `Packages/Tests/VisualsTests/ZodiacLayerTests.swift`

**Asset handling:** The design-assets `Zodiac/Signs/` and `Zodiac/Сonstellations/` folders each contain 12 sign-specific SVGs. When copying, normalize names to `aries.svg`, `taurus.svg`, etc. (lowercase, matching `ZodiacSign.rawValue`). Same convention for both figurative and constellation variants, with a suffix: `aries_figure.svg` and `aries_constellation.svg`.

- [ ] **Step 1: Inspect + copy assets**

```bash
ls /Users/adam/Projects/cc/design-assets/Zodiac/Signs
ls /Users/adam/Projects/cc/design-assets/Zodiac/Сonstellations
```

Verify filenames. If they don't map cleanly to the 12 zodiac signs, report NEEDS_CONTEXT.

Otherwise copy with renamed filenames:

```bash
mkdir -p /Users/adam/Projects/cc/Packages/Sources/Visuals/Resources/Zodiac

# Example for one sign — repeat for all 12 signs ensuring correct source-to-dest naming.
# Actual filenames may differ; adjust based on what `ls` showed.
# Check design-assets names and map to: aries, taurus, gemini, cancer, leo, virgo,
#                                       libra, scorpio, sagittarius, capricorn, aquarius, pisces
```

If the source SVG filenames differ meaningfully from our enum rawValues, do a one-off bash rename loop. If unclear which source file maps to which sign, stop and ask.

- [ ] **Step 2: Implement ZodiacLayer**

`Packages/Sources/Visuals/Layers/ZodiacLayer.swift`:
```swift
import SwiftUI
import CoreModels

public struct ZodiacLayer: View {

    public let sign: ZodiacSign
    public let attitude: DeviceAttitude
    public let variant: Variant

    public enum Variant: Sendable {
        case figure         // illustrated sign
        case constellation  // line-art constellation
    }

    public init(sign: ZodiacSign, attitude: DeviceAttitude, variant: Variant = .figure) {
        self.sign = sign
        self.attitude = attitude
        self.variant = variant
    }

    public var body: some View {
        Image(Self.assetName(for: sign, variant: variant), bundle: .module)
            .resizable()
            .scaledToFit()
            .offset(Self.translation(for: attitude))
    }

    static func assetName(for sign: ZodiacSign, variant: Variant) -> String {
        let suffix: String
        switch variant {
        case .figure: suffix = "_figure"
        case .constellation: suffix = "_constellation"
        }
        return sign.rawValue + suffix
    }

    /// Subtle parallax — 4pt max translation on tilt.
    static func translation(for attitude: DeviceAttitude) -> CGSize {
        CGSize(
            width: CGFloat(attitude.roll) * 4,
            height: CGFloat(attitude.pitch) * 4
        )
    }
}
```

- [ ] **Step 3: Tests**

`Packages/Tests/VisualsTests/ZodiacLayerTests.swift`:
```swift
import Testing
import Foundation
import CoreModels
@testable import Visuals

@Suite struct ZodiacLayerTests {

    @Test func figureAssetsExistForAllSigns() {
        let bundle = Bundle.module
        for sign in ZodiacSign.allCases {
            let name = ZodiacLayer.assetName(for: sign, variant: .figure)
            let url = bundle.url(forResource: name, withExtension: "svg", subdirectory: "Zodiac")
                ?? bundle.url(forResource: name, withExtension: "svg")
            #expect(url != nil, "Missing zodiac figure asset: \(name)")
        }
    }

    @Test func constellationAssetsExistForAllSigns() {
        let bundle = Bundle.module
        for sign in ZodiacSign.allCases {
            let name = ZodiacLayer.assetName(for: sign, variant: .constellation)
            let url = bundle.url(forResource: name, withExtension: "svg", subdirectory: "Zodiac")
                ?? bundle.url(forResource: name, withExtension: "svg")
            #expect(url != nil, "Missing zodiac constellation asset: \(name)")
        }
    }

    @Test func flatAttitudeHasZeroTranslation() {
        let t = ZodiacLayer.translation(for: .zero)
        #expect(t.width == 0 && t.height == 0)
    }
}
```

- [ ] **Step 4: Verify + commit**

`cd /Users/adam/Projects/cc/Packages && swift test --filter ZodiacLayerTests` → 3 pass.

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/Visuals/Resources/Zodiac \
        Packages/Sources/Visuals/Layers/ZodiacLayer.swift \
        Packages/Tests/VisualsTests/ZodiacLayerTests.swift
git commit -m "$(cat <<'EOF'
feat(visuals): add ZodiacLayer with figure + constellation variants

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Visuals — Holographic text / location / zodiac views

**Files:**
- Create: `Packages/Sources/Visuals/Holographic/HolographicText.swift`
- Create: `Packages/Sources/Visuals/Holographic/HolographicLocation.swift`
- Create: `Packages/Sources/Visuals/Holographic/HolographicZodiac.swift`
- Create: `Packages/Tests/VisualsTests/HolographicViewsTests.swift`

- [ ] **Step 1: HolographicText**

`Packages/Sources/Visuals/Holographic/HolographicText.swift`:
```swift
import SwiftUI
import CoreModels
import DesignSystem

public struct HolographicText: View {

    public let text: String
    public let attitude: DeviceAttitude
    public let font: Font

    public init(text: String, attitude: DeviceAttitude, font: Font = CCDesign.Typography.title) {
        self.text = text
        self.attitude = attitude
        self.font = font
    }

    public var body: some View {
        ZStack {
            Text(text)
                .font(font)
                .foregroundStyle(.white)
                .blendMode(.lighten)
                .offset(x: CGFloat(attitude.roll) * 8, y: CGFloat(attitude.pitch) * 8)

            Text(text)
                .font(font)
                .foregroundStyle(.white)
                .blendMode(.luminosity)
                .rotationEffect(.degrees(attitude.roll * 3))
        }
    }
}
```

- [ ] **Step 2: HolographicLocation**

`Packages/Sources/Visuals/Holographic/HolographicLocation.swift`:
```swift
import SwiftUI
import CoreModels
import DesignSystem

public struct HolographicLocation: View {

    public let address: String
    public let attitude: DeviceAttitude

    public init(address: String, attitude: DeviceAttitude) {
        self.address = address
        self.attitude = attitude
    }

    public var body: some View {
        ZStack {
            Text(address)
                .font(CCDesign.Typography.caption1)
                .foregroundStyle(.white)
                .blendMode(.lighten)
                .blur(radius: 2)
                .offset(x: CGFloat(attitude.roll) * 8, y: CGFloat(attitude.pitch) * 8)

            Text(address)
                .font(CCDesign.Typography.caption1)
                .foregroundStyle(.white)
                .blendMode(.luminosity)
        }
    }
}
```

- [ ] **Step 3: HolographicZodiac**

`Packages/Sources/Visuals/Holographic/HolographicZodiac.swift`:
```swift
import SwiftUI
import CoreModels

public struct HolographicZodiac: View {

    public let sign: ZodiacSign
    public let attitude: DeviceAttitude

    public init(sign: ZodiacSign, attitude: DeviceAttitude) {
        self.sign = sign
        self.attitude = attitude
    }

    public var body: some View {
        // Just translates — no rotation. Figurative asset already has holographic rendering baked in.
        ZodiacLayer(sign: sign, attitude: attitude, variant: .figure)
            .blendMode(.luminosity)
    }
}
```

- [ ] **Step 4: Tests**

`Packages/Tests/VisualsTests/HolographicViewsTests.swift`:
```swift
import Testing
import SwiftUI
import CoreModels
@testable import Visuals

@Suite struct HolographicViewsTests {

    @Test func holographicTextInstantiates() {
        _ = HolographicText(text: "Jane", attitude: .zero).body
    }

    @Test func holographicLocationInstantiates() {
        _ = HolographicLocation(address: "1200 TREAT AVE", attitude: .zero).body
    }

    @Test func holographicZodiacInstantiates() {
        _ = HolographicZodiac(sign: .virgo, attitude: .zero).body
    }
}
```

- [ ] **Step 5: Verify + commit**

`swift test --filter HolographicViewsTests` → 3 pass.

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/Visuals/Holographic Packages/Tests/VisualsTests/HolographicViewsTests.swift
git commit -m "$(cat <<'EOF'
feat(visuals): add HolographicText, HolographicLocation, HolographicZodiac

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Visuals — PhotoLayer

**Files:**
- Create: `Packages/Sources/Visuals/Layers/PhotoLayer.swift`
- Create: `Packages/Tests/VisualsTests/PhotoLayerTests.swift`

Card variant: one Image with `.blendMode(.luminosity).opacity(0.6)`.

Recommended variant (designed-in, not rendered in v1): two stacked copies, bottom `.luminosity`, top `.color`, circular crop.

- [ ] **Step 1: Implement**

`Packages/Sources/Visuals/Layers/PhotoLayer.swift`:
```swift
import SwiftUI

public struct PhotoLayer: View {

    public let image: Image
    public let style: Style

    public enum Style: Sendable {
        case card
        case recommended  // Phase 3 — designed-in, still renders correctly
    }

    public init(image: Image, style: Style = .card) {
        self.image = image
        self.style = style
    }

    public var body: some View {
        switch style {
        case .card:
            image
                .resizable()
                .scaledToFill()
                .blendMode(.luminosity)
                .opacity(0.6)
        case .recommended:
            ZStack {
                image.resizable().scaledToFill().blendMode(.luminosity)
                image.resizable().scaledToFill().blendMode(.color)
            }
            .clipShape(Circle())
        }
    }
}
```

- [ ] **Step 2: Tests**

`Packages/Tests/VisualsTests/PhotoLayerTests.swift`:
```swift
import Testing
import SwiftUI
@testable import Visuals

@Suite struct PhotoLayerTests {

    @Test func cardStyleInstantiates() {
        let layer = PhotoLayer(image: Image(systemName: "photo"), style: .card)
        _ = layer.body
    }

    @Test func recommendedStyleInstantiates() {
        let layer = PhotoLayer(image: Image(systemName: "photo"), style: .recommended)
        _ = layer.body
    }
}
```

- [ ] **Step 3: Verify + commit**

`swift test --filter PhotoLayerTests` → 2 pass.

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/Visuals/Layers/PhotoLayer.swift Packages/Tests/VisualsTests/PhotoLayerTests.swift
git commit -m "$(cat <<'EOF'
feat(visuals): add PhotoLayer with card + recommended variants

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Visuals — CardView composition

**Files:**
- Create: `Packages/Sources/Visuals/CardSize.swift`
- Create: `Packages/Sources/Visuals/CardView.swift`
- Create: `Packages/Tests/VisualsTests/CardViewTests.swift`

The public entry point that composes every layer.

- [ ] **Step 1: CardSize**

`Packages/Sources/Visuals/CardSize.swift`:
```swift
import Foundation

public enum CardSize: Sendable {
    case small   // list item
    case medium  // modal preview
    case large   // fullscreen
}
```

- [ ] **Step 2: CardView**

The CardView composes layers. Since we don't yet have a lookup for the per-record guilloche paths (the Generated/ files are developer-local), CardView leaves the Rotation and Blend layers as dependencies passed in by the caller. A `CardPathProvider` protocol abstracts this — in Plan 3, `AppFeature` provides a real implementation that reads from the generated files.

`Packages/Sources/Visuals/CardView.swift`:
```swift
import SwiftUI
import CoreModels
import DesignSystem

public protocol CardPathProvider: Sendable {
    func rotationPaths(for letter: Character) -> [Path]
    func blendPaths(for letter: Character, shape: GuillocheShape, density: CCVisuals.Guilloche.LineDensity) -> [Path]
}

public struct CardView: View {

    public let record: Record
    public let size: CardSize
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let photo: Image?

    public init(
        record: Record,
        size: CardSize,
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        photo: Image? = nil
    ) {
        self.record = record
        self.size = size
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
    }

    public var body: some View {
        let accoutrements = record.accoutrements
        let density: CCVisuals.Guilloche.LineDensity = size == .small ? .preview : .cards

        return ZStack {
            // 1. Gradient base + transfusion
            GradientLayer(timeOfDay: record.metadata.timeOfDay, attitude: attitude)

            // 3. Rotation background
            GuillocheRotationLayer(paths: paths.rotationPaths(for: accoutrements.letter))

            // 4. Photo or letter-blend
            if let photo {
                PhotoLayer(image: photo, style: .card)
            } else {
                GuillocheBlendLayer(
                    paths: paths.blendPaths(
                        for: accoutrements.letter,
                        shape: accoutrements.guillocheShape,
                        density: density
                    ),
                    density: density,
                    attitude: attitude
                )
            }

            // 5. Zodiac (if set)
            if let sign = record.zodiacSign {
                HolographicZodiac(sign: sign, attitude: attitude)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
            }

            // 6. Moon phase
            MoonPhaseLayer(phase: record.metadata.moonPhase)
                .frame(width: 24, height: 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(8)

            // 7. Card text (name + description + location + date)
            CardTextLayer(record: record, attitude: attitude, size: size)
        }
    }
}

struct CardTextLayer: View {
    let record: Record
    let attitude: DeviceAttitude
    let size: CardSize

    var body: some View {
        VStack(alignment: .leading) {
            HolographicText(text: record.name, attitude: attitude)
            if !record.description.isEmpty {
                Text(record.description)
                    .font(CCDesign.Typography.descriptionSmall)
                    .foregroundStyle(.white)
            }
            Spacer()
            if let location = record.location?.label {
                HolographicLocation(address: location, attitude: attitude)
            }
        }
        .padding()
    }
}
```

- [ ] **Step 3: Test fake CardPathProvider**

`Packages/Tests/VisualsTests/CardViewTests.swift`:
```swift
import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import Visuals

struct StubCardPathProvider: CardPathProvider {
    func rotationPaths(for letter: Character) -> [Path] { [] }
    func blendPaths(for letter: Character, shape: GuillocheShape, density: CCVisuals.Guilloche.LineDensity) -> [Path] { [] }
}

@Suite struct CardViewTests {

    private func sampleRecord(zodiac: ZodiacSign? = nil) -> Record {
        Record(
            id: UUID(),
            name: "Jane",
            description: "Met at the coffee shop",
            photoID: nil,
            location: LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 TREAT AVE"),
            zodiacSign: zodiac,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
        )
    }

    @Test func cardInstantiatesAtAllSizes() {
        let record = sampleRecord(zodiac: .virgo)
        let provider = StubCardPathProvider()
        _ = CardView(record: record, size: .small, attitude: .zero, paths: provider).body
        _ = CardView(record: record, size: .medium, attitude: .zero, paths: provider).body
        _ = CardView(record: record, size: .large, attitude: .zero, paths: provider).body
    }

    @Test func cardInstantiatesWithoutZodiac() {
        let record = sampleRecord(zodiac: nil)
        _ = CardView(record: record, size: .medium, attitude: .zero, paths: StubCardPathProvider()).body
    }

    @Test func cardInstantiatesWithPhoto() {
        let record = sampleRecord()
        _ = CardView(
            record: record,
            size: .medium,
            attitude: .zero,
            paths: StubCardPathProvider(),
            photo: Image(systemName: "photo")
        ).body
    }
}
```

- [ ] **Step 4: Verify + commit**

`cd /Users/adam/Projects/cc/Packages && swift test --filter CardViewTests` → 3 pass. Full suite green.

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/Visuals/CardSize.swift \
        Packages/Sources/Visuals/CardView.swift \
        Packages/Tests/VisualsTests/CardViewTests.swift
git commit -m "$(cat <<'EOF'
feat(visuals): add CardView composition entry point + CardPathProvider

CardView composes every layer — gradient, guilloche rotation background,
photo-or-blend foreground, zodiac, moon phase, holographic card text —
parameterized by Record, CardSize, DeviceAttitude. Guilloche paths are
injected via a CardPathProvider protocol so the developer-local
Generated/ files stay behind a seam.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Snapshot baseline + final verification

**Files:**
- Create: `Packages/Tests/VisualsTests/CardSnapshotTests.swift`
- (Snapshot files auto-generated on first run, committed to repo)

Use swift-snapshot-testing to establish a baseline for each card size × representative states.

- [ ] **Step 1: Snapshot test**

`Packages/Tests/VisualsTests/CardSnapshotTests.swift`:
```swift
#if canImport(UIKit)
import Testing
import SwiftUI
import UIKit
import SnapshotTesting
import Foundation
import CoreModels
@testable import Visuals

@Suite struct CardSnapshotTests {

    private func makeRecord(
        id: UUID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!,
        timeOfDay: TimeOfDay = .sunset,
        moonPhase: MoonPhase = .fullMoon,
        zodiac: ZodiacSign? = .virgo,
        name: String = "Jane"
    ) -> Record {
        Record(
            id: id,
            name: name,
            description: "Met at the coffee shop",
            photoID: nil,
            location: LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 TREAT AVE, SAN FRANCISCO"),
            zodiacSign: zodiac,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            metadata: RecordMetadata(timeOfDay: timeOfDay, moonPhase: moonPhase)
        )
    }

    @Test func mediumCardSunsetFullMoon() {
        let view = CardView(
            record: makeRecord(),
            size: .medium,
            attitude: .zero,
            paths: StubCardPathProvider()
        )
        let controller = UIHostingController(rootView: view.frame(width: 335, height: 211).background(.black))
        assertSnapshot(of: controller, as: .image(size: CGSize(width: 335, height: 211)))
    }

    @Test func largeCardNightFullMoon() {
        let view = CardView(
            record: makeRecord(timeOfDay: .night, moonPhase: .fullMoon, zodiac: nil),
            size: .large,
            attitude: .zero,
            paths: StubCardPathProvider()
        )
        let controller = UIHostingController(rootView: view.frame(width: 375, height: 600).background(.black))
        assertSnapshot(of: controller, as: .image(size: CGSize(width: 375, height: 600)))
    }

    @Test func smallCardMiddayNewMoon() {
        let view = CardView(
            record: makeRecord(timeOfDay: .midday, moonPhase: .newMoon, zodiac: .aries),
            size: .small,
            attitude: .zero,
            paths: StubCardPathProvider()
        )
        let controller = UIHostingController(rootView: view.frame(width: 335, height: 120).background(.black))
        assertSnapshot(of: controller, as: .image(size: CGSize(width: 335, height: 120)))
    }

    @Test func mediumCardTiltedAttitude() {
        let view = CardView(
            record: makeRecord(),
            size: .medium,
            attitude: DeviceAttitude(pitch: 0.3, roll: -0.5),
            paths: StubCardPathProvider()
        )
        let controller = UIHostingController(rootView: view.frame(width: 335, height: 211).background(.black))
        assertSnapshot(of: controller, as: .image(size: CGSize(width: 335, height: 211)))
    }
}
#endif
```

- [ ] **Step 2: Run to record baselines**

First run will fail (no reference images) and write them to disk. Run twice:

```bash
cd /Users/adam/Projects/cc/Packages && swift test --filter CardSnapshotTests
# Expect first run to fail with "recorded new snapshot" — this is normal.
cd /Users/adam/Projects/cc/Packages && swift test --filter CardSnapshotTests
# Expect second run to pass.
```

The snapshot library writes reference images into `Packages/Tests/VisualsTests/__Snapshots__/`. These get committed to source control.

**Note:** snapshots are only recorded on iOS / iPadOS / tvOS (via UIKit). On macOS host, the `#if canImport(UIKit)` guard skips the tests entirely. If you want snapshots to run on macOS too, swap `UIHostingController` for `NSHostingController` inside an `#elseif canImport(AppKit)` branch — not required for v1.

- [ ] **Step 3: Full suite + commit**

`cd /Users/adam/Projects/cc/Packages && swift test`
Expected: All tests green (some snapshot tests may be skipped on macOS host).

```bash
cd /Users/adam/Projects/cc
git add Packages/Tests/VisualsTests/
git commit -m "$(cat <<'EOF'
test(visuals): add CardView snapshot baseline

Captures reference images for Medium/Large/Small cards at representative
metadata combinations + one tilted attitude. Future visual regressions
will fail these snapshots with clear pixel diffs.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## What's done

Plan 2 produces:
- `DesignSystem` module with color tokens, typography scale, bundled fonts, linear gradients
- `Visuals` module with all 7 layer views and a `CardView` composition
- `Tools/SVGToSwift` CLI for converting designer SVGs into Swift Path constants
- `Tools/regenerate-svg.sh` developer script
- Snapshot test baseline for 4 representative card states

All 15 tasks deliver tests; the full suite should exceed 100 passing tests by the end of Plan 2 (≈76 from Plan 1 + ≈35 new).

## Known follow-ups for Plan 3

- Concrete `CardPathProvider` implementation that reads from `Generated/` (wired into `AppFeature`)
- Font registration via `CTFontManager` at app launch
- Snapshot tests for iPhone 13 baseline device at various Dynamic Type sizes
- Gradient refinement: the 3-stop LinearGradient is a simplification of the PNGs' sheen — consider RadialGradient or multi-stop approximation if visual QA finds it too flat
