# Plan 6 — Create-Flow Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current create-record scene with the Figma `L_Add_new_Name_1P` design — inline editable pills on top of the card atmosphere, autofilled location/time strip, full-width SAVE button — while extracting a shared `CardBackdrop` from `CardView`.

**Architecture:** The atmospheric layers (gradient + guilloche + photo-or-blend-letter) become a reusable `CardBackdrop` view in `Visuals`. `CardView` composes `CardBackdrop` + its existing zodiac/moon overlays + text layer, unchanged visually. `CreateRecordScene` composes `CardBackdrop` + new create-specific zodiac/moon badges + editable form overlay + location/time strip + save button. All create-specific components live in `FeatureCreate`. Photo picker uses SwiftUI's native `PhotosPicker` inline (no injected service). Zodiac is display-only with a random sign for now; picker wiring deferred.

**Tech Stack:** SwiftUI, Swift 6 strict concurrency, Swift Testing, `swift-snapshot-testing` (pointfreeco), `PhotosUI` (iOS 16+).

**Spec reference:** `docs/superpowers/specs/2026-04-19-create-flow-redesign-design.md`.

**Figma reference:** `L_Add_new_Name_1P` node `185:8911` (primary), `D_Add_new_Name_2P` node `300:11705` (placeholder styling reference). File key `aYjd42Fr66HRCV0vQcJAtS`.

---

## File Structure

### New files

**In `Packages/Sources/Visuals/`:**
- `CardBackdrop.swift` — public view containing just the atmospheric z-stack (gradient → guilloche rotation → silhouette → photo-or-blend-letter).
- `VisualsBundle.swift` — public `CCVisuals.bundle: Bundle` accessor so `FeatureCreate` can load shared SVG assets (constellation/figure/moon).

**In `Packages/Sources/FeatureCreate/`:**
- `PersonTopNav.swift` — top bar: Cancel / PERSON / + Person (disabled).
- `CreateFormOverlay.swift` — + Add Photo button (with inline `PhotosPicker`), name `TextField` pill, description `TextField` pill.
- `LocationTimeStrip.swift` — glass strip under the card; address + hologram pin on left, date/time on right, hairline separator.
- `SaveButton.swift` — full-width 50pt button with time-of-day gradient.
- `Badges/CreateConstellationBadge.swift` — 100×90 constellation (right-edge top).
- `Badges/CreateZodiacSymbolBadge.swift` — 35×32 holographic zodiac figure (right-edge bottom-left).
- `Badges/CreateMoonPhaseBadge.swift` — 35×56 moon frame + phase glyph (right-edge bottom-right).

**In `Packages/Tests/`:**
- `VisualsTests/CardBackdropTests.swift` — instantiation smoke tests.
- `VisualsTests/VisualsBundleTests.swift` — bundle accessor loads a known asset.
- `FeatureCreateTests/PersonTopNavTests.swift`
- `FeatureCreateTests/CreateFormOverlayTests.swift`
- `FeatureCreateTests/LocationTimeStripTests.swift` — formatter unit tests + instantiation.
- `FeatureCreateTests/SaveButtonTests.swift`
- `FeatureCreateTests/Badges/CreateConstellationBadgeTests.swift`
- `FeatureCreateTests/Badges/CreateZodiacSymbolBadgeTests.swift`
- `FeatureCreateTests/Badges/CreateMoonPhaseBadgeTests.swift`
- `FeatureCreateTests/CreateRecordSceneTests.swift` — scene instantiation + save-enable behavior.

### Modified files

- `Packages/Sources/Visuals/CardView.swift` — replace inline `backdrop(...)` with a `CardBackdrop` composition; keep zodiac/moon/text layers unchanged.
- `Packages/Sources/FeatureCreate/CreateRecordModel.swift` — extend with `createdAt`, `metadata`, `location`, `randomZodiacSign` as stored values set at init. Remove the `zodiacSign` editable surface.
- `Packages/Sources/FeatureCreate/CreateRecordScene.swift` — rewrite body to compose the new UI; update `init` signature.
- `Packages/Sources/AppFeature/RootScene.swift` — supply `createdAt`, `metadata`, `location` to `CreateRecordScene`.
- `Packages/Tests/FeatureCreateTests/CreateRecordModelTests.swift` — update existing tests for new init signature + new invariants.
- `Packages/Tests/VisualsTests/CardViewTests.swift` — verify regression post-refactor (tests should continue to pass unchanged).

### Deleted files

- `Packages/Sources/FeatureCreate/CreateFormFields.swift` — fully replaced by `CreateFormOverlay`.

### Untouched

- `Packages/Sources/FeatureCreate/ZodiacPickerSheet.swift` — stays on disk, unused (future picker wiring).
- Existing snapshot tests in `Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/` — used as a regression gate for Task 1.

---

## Commit discipline

After every task's final "Run tests" step passes, commit before moving to the next task. Commit messages follow the existing convention (see `git log --oneline -20`): `feat(scope): short description` or `refactor(scope): …` or `test(scope): …`.

---

## Task 1 — Extract `CardBackdrop` from `CardView`

**Files:**
- Create: `Packages/Sources/Visuals/CardBackdrop.swift`
- Modify: `Packages/Sources/Visuals/CardView.swift`
- Test: `Packages/Tests/VisualsTests/CardBackdropTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/Tests/VisualsTests/CardBackdropTests.swift`:

```swift
import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import Visuals

@MainActor
@Suite struct CardBackdropTests {

    private struct StubPaths: CardPathProvider {
        func rotationPaths(for letter: Character) -> [Path] { [] }
        func blendPaths(for letter: Character, shape: GuillocheShape, density: CCVisuals.Guilloche.LineDensity) -> [Path] { [] }
    }

    private func record(photoID: UUID? = nil) -> Record {
        Record(
            id: UUID(),
            name: "Jane",
            description: "",
            photoID: photoID,
            location: nil,
            zodiacSign: .virgo,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)
        )
    }

    @Test func backdropInstantiatesWithoutPhoto() {
        _ = CardBackdrop(
            record: record(),
            attitude: .zero,
            paths: StubPaths(),
            photo: nil
        ).body
    }

    @Test func backdropInstantiatesWithPhoto() {
        _ = CardBackdrop(
            record: record(photoID: UUID()),
            attitude: .zero,
            paths: StubPaths(),
            photo: Image(systemName: "photo")
        ).body
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages && swift test --filter VisualsTests.CardBackdropTests -q 2>&1 | tail -30`
Expected: FAIL with "cannot find 'CardBackdrop' in scope".

- [ ] **Step 3: Create `CardBackdrop.swift`**

Create `Packages/Sources/Visuals/CardBackdrop.swift`:

```swift
import SwiftUI
import CoreModels
import DesignSystem

/// Atmospheric card backdrop — shared between `CardView` (list rows, detail)
/// and the create flow. Contains only the gradient + guilloche + photo-or-blend
/// layers. Does not render zodiac, moon, or text overlays.
public struct CardBackdrop: View {

    public let record: Record
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let photo: Image?

    @Bindable private var blendTuning = CardBlendTuning.shared

    public init(
        record: Record,
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        photo: Image? = nil
    ) {
        self.record = record
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
    }

    public var body: some View {
        let accoutrements = record.accoutrements
        let density: CCVisuals.Guilloche.LineDensity = .cards

        ZStack {
            GradientLayer(timeOfDay: record.metadata.timeOfDay, attitude: attitude)

            GuillocheRotationLayer(paths: paths.rotationPaths(for: accoutrements.letter))

            BBackgroundSilhouetteLayer(
                paths: GuillocheRotationLayer.swirlPaths(
                    from: paths.rotationPaths(for: accoutrements.letter).first
                )
            )

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
                    attitude: attitude,
                    tint: .white,
                    depthScale: blendTuning.depthScale,
                    reversed: true
                )
                .frame(width: 184, height: 160)
                .opacity(0.55)
            }
        }
    }
}
```

- [ ] **Step 4: Refactor `CardView.swift` to use `CardBackdrop`**

In `Packages/Sources/Visuals/CardView.swift`, replace the `private func backdrop(...)` method and its usage. Change the `body` so the `ZStack` composes `CardBackdrop` + the existing zodiac/moon overlays + text layer:

```swift
public var body: some View {
    let accoutrements = record.accoutrements
    let density: CCVisuals.Guilloche.LineDensity = .cards

    return GeometryReader { geo in
        let layout = CardLayout(size: geo.size)
        ZStack {
            let backdropView = backdrop(accoutrements: accoutrements, density: density, layout: layout)
            backdropView

            CardTextLayer(
                record: record,
                attitude: attitude,
                layout: layout,
                coordinateSpaceName: Self.cardCoordinateSpace,
                backdrop: { backdrop(accoutrements: accoutrements, density: density, layout: layout) }
            )
        }
        .frame(width: geo.size.width, height: geo.size.height)
        .clipped()
        .coordinateSpace(.named(Self.cardCoordinateSpace))
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.accessibilityLabel(for: record))
}

@ViewBuilder
private func backdrop(
    accoutrements: VisualAccoutrements,
    density: CCVisuals.Guilloche.LineDensity,
    layout: CardLayout
) -> some View {
    ZStack {
        CardBackdrop(record: record, attitude: attitude, paths: paths, photo: photo)

        // Zodiac stars (constellation): 100×90 at right-edge, vertically centered.
        if let sign = record.zodiacSign {
            ZodiacLayer(sign: sign, attitude: attitude, variant: .constellation)
                .frame(width: 100, height: 90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .accessibilityHidden(true)
        }

        // Zodiac symbol (figure) with holographic luminosity: 35×32.
        if let sign = record.zodiacSign {
            HolographicZodiac(sign: sign, attitude: attitude)
                .frame(width: 35, height: 32)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 72, trailing: 57))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }

        // Moon phase frame: 34×56, bottom-trailing.
        MoonPhaseLayer(phase: record.metadata.moonPhase)
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 54))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}
```

Note: the `backdrop(...)` helper stays so `CardTextLayer`'s `backdrop:` closure (used for `BackdropBlurPill` sampling) still resolves correctly.

- [ ] **Step 5: Run all Visuals tests to verify no regression**

Run: `cd Packages && swift test --filter VisualsTests -q 2>&1 | tail -50`
Expected: PASS — CardBackdrop instantiates, all existing CardView tests still pass.

- [ ] **Step 6: Run CardSnapshotTests on the simulator to confirm zero visual regression**

Run:
```bash
cd /Users/adam/Projects/casual-contacts-contact-create-ui-fixes/Packages
xcodebuild test \
    -scheme CasualContactsPackages-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:VisualsTests/CardSnapshotTests 2>&1 | tail -30
```
Expected: PASS. Committed snapshot PNGs at `Packages/Tests/VisualsTests/__Snapshots__/CardSnapshotTests/` match pixel-for-pixel.

- [ ] **Step 7: Commit**

```bash
git add Packages/Sources/Visuals/CardBackdrop.swift Packages/Sources/Visuals/CardView.swift Packages/Tests/VisualsTests/CardBackdropTests.swift
git commit -m "refactor(visuals): extract CardBackdrop from CardView"
```

---

## Task 2 — Public `CCVisuals.bundle` accessor

**Files:**
- Create: `Packages/Sources/Visuals/VisualsBundle.swift`
- Test: `Packages/Tests/VisualsTests/VisualsBundleTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/Tests/VisualsTests/VisualsBundleTests.swift`:

```swift
import Testing
import Foundation
@testable import Visuals

@Suite struct VisualsBundleTests {

    @Test func bundleCanLoadKnownZodiacAsset() throws {
        let bundle = CCVisuals.bundle
        // The Visuals target compiles Zodiac.xcassets via `.process("Resources")`.
        // `Virgo_constellation` is one of the named images in that catalog.
        let url = bundle.url(forResource: "Virgo_constellation", withExtension: nil)
        // NSDataAsset is the API that reads from compiled asset catalogs.
        let asset = NSDataAsset(name: "Virgo_constellation", bundle: bundle)
        #expect(asset != nil || url != nil,
                "CCVisuals.bundle should expose the Visuals asset catalog")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages && swift test --filter VisualsTests.VisualsBundleTests -q 2>&1 | tail -20`
Expected: FAIL with "type 'CCVisuals' has no member 'bundle'".

- [ ] **Step 3: Add the accessor**

Create `Packages/Sources/Visuals/VisualsBundle.swift`:

```swift
import Foundation

public extension CCVisuals {
    /// Public bundle accessor so downstream modules (e.g. FeatureCreate) can
    /// load shared SVG assets from the Visuals asset catalogs via
    /// `Image(name:bundle: CCVisuals.bundle)` or `NSDataAsset(name:bundle:)`.
    static var bundle: Bundle { .module }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages && swift test --filter VisualsTests.VisualsBundleTests -q 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/Visuals/VisualsBundle.swift Packages/Tests/VisualsTests/VisualsBundleTests.swift
git commit -m "feat(visuals): expose public bundle accessor for shared assets"
```

---

## Task 3 — Extend `CreateRecordModel`

Signature change: the model now takes `createdAt`, `metadata`, and `location` at init time (previously derived via a separate `updatePreviewMetadata` call). It also generates a stable random zodiac sign per instance.

**Files:**
- Modify: `Packages/Sources/FeatureCreate/CreateRecordModel.swift`
- Modify: `Packages/Tests/FeatureCreateTests/CreateRecordModelTests.swift`

- [ ] **Step 1: Update the tests to the new surface**

Replace the contents of `Packages/Tests/FeatureCreateTests/CreateRecordModelTests.swift` with:

```swift
import Testing
import Foundation
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct CreateRecordModelTests {

    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)  // 2023-11-14 22:13:20 UTC
    private let metadata = RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
    private let location = LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 Treat Ave, San Francisco")

    private func makeModel() -> CreateRecordModel {
        CreateRecordModel(createdAt: fixedDate, metadata: metadata, location: location)
    }

    @Test func emptyFormIsNotSaveable() {
        let model = makeModel()
        #expect(!model.isSaveable)
    }

    @Test func whitespaceOnlyNameIsNotSaveable() {
        let model = makeModel()
        model.name = "   "
        #expect(!model.isSaveable)
    }

    @Test func nonEmptyNameIsSaveable() {
        let model = makeModel()
        model.name = "Jane"
        #expect(model.isSaveable)
    }

    @Test func createdAtIsFixedAtInit() {
        let model = makeModel()
        #expect(model.createdAt == fixedDate)
    }

    @Test func metadataIsStoredVerbatim() {
        let model = makeModel()
        #expect(model.metadata.timeOfDay == .sunset)
        #expect(model.metadata.moonPhase == .fullMoon)
    }

    @Test func locationIsStoredVerbatim() {
        let model = makeModel()
        #expect(model.location?.label == "1200 Treat Ave, San Francisco")
    }

    @Test func randomZodiacSignIsOneOfAllCases() {
        let model = makeModel()
        #expect(ZodiacSign.allCases.contains(model.randomZodiacSign))
    }

    @Test func randomZodiacSignIsStableAcrossReads() {
        let model = makeModel()
        let first = model.randomZodiacSign
        let second = model.randomZodiacSign
        let third = model.randomZodiacSign
        #expect(first == second)
        #expect(second == third)
    }

    @Test func previewRecordMirrorsModelState() {
        let model = makeModel()
        model.name = "Alex"
        model.description = "Met at the festival"
        let record = model.previewRecord
        #expect(record.name == "Alex")
        #expect(record.description == "Met at the festival")
        #expect(record.location?.label == "1200 Treat Ave, San Francisco")
        #expect(record.zodiacSign == model.randomZodiacSign)
        #expect(record.metadata.timeOfDay == .sunset)
        #expect(record.metadata.moonPhase == .fullMoon)
        #expect(record.createdAt == fixedDate)
    }

    @Test func draftUsesRandomZodiacSign() {
        let model = makeModel()
        model.name = "Jane"
        model.description = "Met at cafe"
        let draft = model.draft
        #expect(draft.name == "Jane")
        #expect(draft.description == "Met at cafe")
        #expect(draft.zodiacSign == model.randomZodiacSign)
        #expect(draft.location?.label == "1200 Treat Ave, San Francisco")
    }

    @Test func draftCarriesPhotoData() {
        let model = makeModel()
        model.name = "Jane"
        model.photoData = Data([0xFF, 0xD8, 0xFF])  // JPEG magic bytes
        #expect(model.draft.photo == Data([0xFF, 0xD8, 0xFF]))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Packages && swift test --filter FeatureCreateTests -q 2>&1 | tail -40`
Expected: FAIL with "missing argument for parameter" or "has no member 'createdAt'".

- [ ] **Step 3: Rewrite `CreateRecordModel.swift`**

Replace the entire contents of `Packages/Sources/FeatureCreate/CreateRecordModel.swift` with:

```swift
import Foundation
import SwiftUI
import Observation
import CoreModels

/// Editable form state for the create-record flow. Owns the name, description,
/// and photo data that the user types/picks. All other fields (`createdAt`,
/// `metadata`, `location`, `randomZodiacSign`) are fixed at init: they reflect
/// the ambient context at the moment the sheet opened.
@MainActor
@Observable
public final class CreateRecordModel {

    // User-editable state.
    public var name: String = ""
    public var description: String = ""
    public var photoData: Data?

    // Fixed at init — non-editable.
    public let createdAt: Date
    public let metadata: RecordMetadata
    public let location: LocationInfo?

    /// A random sign chosen once per instance. Temporary: the real zodiac
    /// picker replaces this in a later plan. Visible-only; does not drive
    /// interactive state.
    public let randomZodiacSign: ZodiacSign

    public init(
        createdAt: Date,
        metadata: RecordMetadata,
        location: LocationInfo?,
        randomZodiacSign: ZodiacSign? = nil
    ) {
        self.createdAt = createdAt
        self.metadata = metadata
        self.location = location
        // `allCases.randomElement()` returns nil only on empty collections.
        // ZodiacSign has 12 cases, so the force-unwrap is safe.
        self.randomZodiacSign = randomZodiacSign ?? ZodiacSign.allCases.randomElement()!
    }

    public var isSaveable: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var draft: RecordDraft {
        RecordDraft(
            name: name,
            description: description,
            photo: photoData,
            location: location,
            zodiacSign: randomZodiacSign
        )
    }

    /// Provisional `Record` used to drive the `CardBackdrop` preview while the
    /// user is still editing. The ID is stable within-instance but not final;
    /// the persisted record gets a fresh ID at save time via `RecordStore`.
    public var previewRecord: Record {
        Record(
            id: previewID,
            name: name,
            description: description,
            photoID: photoData == nil ? nil : previewPhotoID,
            location: location,
            zodiacSign: randomZodiacSign,
            createdAt: createdAt,
            updatedAt: createdAt,
            metadata: metadata
        )
    }

    private let previewID = UUID()
    private let previewPhotoID = UUID()
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Packages && swift test --filter FeatureCreateTests.CreateRecordModelTests -q 2>&1 | tail -30`
Expected: PASS — all 12 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/FeatureCreate/CreateRecordModel.swift Packages/Tests/FeatureCreateTests/CreateRecordModelTests.swift
git commit -m "refactor(create): make CreateRecordModel take createdAt/metadata/location at init"
```

---

## Task 4 — `CreateConstellationBadge`

**Files:**
- Create: `Packages/Sources/FeatureCreate/Badges/CreateConstellationBadge.swift`
- Test: `Packages/Tests/FeatureCreateTests/Badges/CreateConstellationBadgeTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/Tests/FeatureCreateTests/Badges/CreateConstellationBadgeTests.swift`:

```swift
import Testing
import SwiftUI
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct CreateConstellationBadgeTests {

    @Test func instantiatesForAllSigns() {
        for sign in ZodiacSign.allCases {
            _ = CreateConstellationBadge(sign: sign, attitude: .zero).body
        }
    }

    @Test func instantiatesWithTiltedAttitude() {
        _ = CreateConstellationBadge(
            sign: .cancer,
            attitude: DeviceAttitude(roll: 0.3, pitch: -0.2)
        ).body
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages && swift test --filter FeatureCreateTests.Badges.CreateConstellationBadgeTests -q 2>&1 | tail -20`
Expected: FAIL with "cannot find 'CreateConstellationBadge' in scope".

- [ ] **Step 3: Create the view**

Create `Packages/Sources/FeatureCreate/Badges/CreateConstellationBadge.swift`:

```swift
import SwiftUI
import CoreModels
import Visuals

/// Right-edge constellation stars for the create flow. 100×90, decorative-only.
/// Shares the `{sign}_constellation` asset with the card's `ZodiacLayer` but
/// does not reuse that view because the create flow's composition and sizing
/// are different (no attitude-scaled offset normalization, no parent alignment
/// hook — just a fixed-frame static image with mild parallax).
struct CreateConstellationBadge: View {
    let sign: ZodiacSign
    let attitude: DeviceAttitude

    var body: some View {
        Image("\(sign.rawValue)_constellation", bundle: CCVisuals.bundle)
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 90)
            .offset(Self.translation(for: attitude))
            .accessibilityHidden(true)
    }

    /// 4pt max parallax on tilt — matches the card's `ZodiacLayer` feel.
    private static func translation(for attitude: DeviceAttitude) -> CGSize {
        CGSize(
            width: CGFloat(attitude.roll) * 4,
            height: CGFloat(attitude.pitch) * 4
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages && swift test --filter FeatureCreateTests.Badges.CreateConstellationBadgeTests -q 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/FeatureCreate/Badges/CreateConstellationBadge.swift Packages/Tests/FeatureCreateTests/Badges/CreateConstellationBadgeTests.swift
git commit -m "feat(create): add CreateConstellationBadge for right-edge stars"
```

---

## Task 5 — `CreateZodiacSymbolBadge`

**Files:**
- Create: `Packages/Sources/FeatureCreate/Badges/CreateZodiacSymbolBadge.swift`
- Test: `Packages/Tests/FeatureCreateTests/Badges/CreateZodiacSymbolBadgeTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/Tests/FeatureCreateTests/Badges/CreateZodiacSymbolBadgeTests.swift`:

```swift
import Testing
import SwiftUI
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct CreateZodiacSymbolBadgeTests {

    @Test func instantiatesForAllSigns() {
        for sign in ZodiacSign.allCases {
            _ = CreateZodiacSymbolBadge(sign: sign, attitude: .zero).body
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages && swift test --filter FeatureCreateTests.Badges.CreateZodiacSymbolBadgeTests -q 2>&1 | tail -20`
Expected: FAIL with "cannot find 'CreateZodiacSymbolBadge' in scope".

- [ ] **Step 3: Create the view**

Create `Packages/Sources/FeatureCreate/Badges/CreateZodiacSymbolBadge.swift`:

```swift
import SwiftUI
import CoreModels
import Visuals

/// Holographic zodiac figure for the create flow. 35×32, decorative-only.
/// Loads the `{sign}_figure` asset directly and applies a luminosity blend
/// mode for the "hologram" feel. Parallels `HolographicZodiac` in the
/// Visuals module but positioned/sized differently for this screen.
struct CreateZodiacSymbolBadge: View {
    let sign: ZodiacSign
    let attitude: DeviceAttitude

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let image = Image("\(sign.rawValue)_figure", bundle: CCVisuals.bundle)
            .resizable()
            .scaledToFit()
            .frame(width: 35, height: 32)
            .offset(Self.translation(for: attitude))
            .accessibilityHidden(true)

        if reduceTransparency {
            image
        } else {
            image.blendMode(.luminosity)
        }
    }

    private static func translation(for attitude: DeviceAttitude) -> CGSize {
        CGSize(
            width: CGFloat(attitude.roll) * 4,
            height: CGFloat(attitude.pitch) * 4
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages && swift test --filter FeatureCreateTests.Badges.CreateZodiacSymbolBadgeTests -q 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/FeatureCreate/Badges/CreateZodiacSymbolBadge.swift Packages/Tests/FeatureCreateTests/Badges/CreateZodiacSymbolBadgeTests.swift
git commit -m "feat(create): add CreateZodiacSymbolBadge for right-edge hologram"
```

---

## Task 6 — `CreateMoonPhaseBadge`

**Files:**
- Create: `Packages/Sources/FeatureCreate/Badges/CreateMoonPhaseBadge.swift`
- Test: `Packages/Tests/FeatureCreateTests/Badges/CreateMoonPhaseBadgeTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/Tests/FeatureCreateTests/Badges/CreateMoonPhaseBadgeTests.swift`:

```swift
import Testing
import SwiftUI
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct CreateMoonPhaseBadgeTests {

    @Test func instantiatesForAllPhases() {
        for phase in MoonPhase.allCases {
            _ = CreateMoonPhaseBadge(phase: phase).body
        }
    }

    @Test func assetNamePreservesSourceTypo() {
        // The SVG filenames use `Waxing_Crescennt` / `Waning_Crescennt` (double-n).
        // The badge must map these enum values back to the source filenames.
        #expect(CreateMoonPhaseBadge.assetName(for: .waxingCrescent) == "Waxing_Crescennt")
        #expect(CreateMoonPhaseBadge.assetName(for: .waningCrescent) == "Waning_Crescennt")
        #expect(CreateMoonPhaseBadge.assetName(for: .newMoon) == "New_Moon")
        #expect(CreateMoonPhaseBadge.assetName(for: .firstQuarter) == "First_Quarter")
        #expect(CreateMoonPhaseBadge.assetName(for: .fullMoon) == "Full_Moon")
        #expect(CreateMoonPhaseBadge.assetName(for: .waxingGibbous) == "Waxing_Gibbous")
        #expect(CreateMoonPhaseBadge.assetName(for: .waningGibbous) == "Waning_Gibbous")
        #expect(CreateMoonPhaseBadge.assetName(for: .thirdQuarter) == "Third_Quarter")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages && swift test --filter FeatureCreateTests.Badges.CreateMoonPhaseBadgeTests -q 2>&1 | tail -20`
Expected: FAIL.

- [ ] **Step 3: Create the view**

Create `Packages/Sources/FeatureCreate/Badges/CreateMoonPhaseBadge.swift`:

```swift
import SwiftUI
import CoreModels
import Visuals

/// Moon phase with the hologram-frame backdrop visible. 35×56 total: a 34×56
/// `Moon_Background` frame with a 20×20 phase glyph pinned to the top center
/// (7pt top inset). Matches Figma `Waning_Crescennt` instance inside the
/// `Zodiac_info` frame.
struct CreateMoonPhaseBadge: View {
    let phase: MoonPhase

    var body: some View {
        Image("Moon_Background", bundle: CCVisuals.bundle)
            .resizable()
            .frame(width: 34, height: 56)
            .overlay(alignment: .top) {
                Image(Self.assetName(for: phase), bundle: CCVisuals.bundle)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .padding(.top, 7)
            }
            .accessibilityHidden(true)
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

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages && swift test --filter FeatureCreateTests.Badges.CreateMoonPhaseBadgeTests -q 2>&1 | tail -20`
Expected: PASS — 2 tests pass (8 phase variants × 2 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/FeatureCreate/Badges/CreateMoonPhaseBadge.swift Packages/Tests/FeatureCreateTests/Badges/CreateMoonPhaseBadgeTests.swift
git commit -m "feat(create): add CreateMoonPhaseBadge with hologram frame"
```

---

## Task 7 — `PersonTopNav`

**Files:**
- Create: `Packages/Sources/FeatureCreate/PersonTopNav.swift`
- Test: `Packages/Tests/FeatureCreateTests/PersonTopNavTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/Tests/FeatureCreateTests/PersonTopNavTests.swift`:

```swift
import Testing
import SwiftUI
@testable import FeatureCreate

@MainActor
@Suite struct PersonTopNavTests {

    @Test func instantiatesWithCallbacks() {
        var cancelCount = 0
        let nav = PersonTopNav(onCancel: { cancelCount += 1 })
        _ = nav.body
        // Sanity: callback is still callable (view doesn't have to invoke it).
        nav.onCancel()
        #expect(cancelCount == 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages && swift test --filter FeatureCreateTests.PersonTopNavTests -q 2>&1 | tail -20`
Expected: FAIL with "cannot find 'PersonTopNav' in scope".

- [ ] **Step 3: Create the view**

Create `Packages/Sources/FeatureCreate/PersonTopNav.swift`:

```swift
import SwiftUI
import DesignSystem

/// Top bar for the create-record sheet. Cancel on the left, PERSON heading
/// centered, `+ Person` disabled placeholder on the right. 44pt tall.
struct PersonTopNav: View {
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            // Heading — centered.
            Text("PERSON")
                .font(CCDesign.Typography.headline)
                .tracking(CCDesign.Typography.Tracking.headline)
                .foregroundStyle(CCDesign.Colors.L2)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Button("Cancel", action: onCancel)
                    .font(.custom("CormorantInfant-SemiBold", size: 18))
                    .foregroundStyle(CCDesign.Colors.L0)
                    .accessibilityIdentifier("cancelCreateButton")

                Spacer()

                // + Person is a placeholder for the deferred 2-person flow.
                // Rendered for visual parity with Figma; not interactive.
                Text("+ Person")
                    .font(.custom("CormorantInfant-SemiBold", size: 18))
                    .foregroundStyle(CCDesign.Colors.L0)
                    .opacity(0.35)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages && swift test --filter FeatureCreateTests.PersonTopNavTests -q 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/FeatureCreate/PersonTopNav.swift Packages/Tests/FeatureCreateTests/PersonTopNavTests.swift
git commit -m "feat(create): add PersonTopNav with cancel + disabled +Person"
```

---

## Task 8 — `CreateFormOverlay` with inline `PhotosPicker`

**Files:**
- Create: `Packages/Sources/FeatureCreate/CreateFormOverlay.swift`
- Test: `Packages/Tests/FeatureCreateTests/CreateFormOverlayTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/Tests/FeatureCreateTests/CreateFormOverlayTests.swift`:

```swift
import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct CreateFormOverlayTests {

    private func makeModel(name: String = "", description: String = "") -> CreateRecordModel {
        let model = CreateRecordModel(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon),
            location: nil
        )
        model.name = name
        model.description = description
        return model
    }

    @Test func instantiatesEmpty() {
        let model = makeModel()
        _ = CreateFormOverlay(model: model).body
    }

    @Test func instantiatesPopulated() {
        let model = makeModel(name: "Adam", description: "Met at midday")
        _ = CreateFormOverlay(model: model).body
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages && swift test --filter FeatureCreateTests.CreateFormOverlayTests -q 2>&1 | tail -20`
Expected: FAIL.

- [ ] **Step 3: Create the view**

Create `Packages/Sources/FeatureCreate/CreateFormOverlay.swift`:

```swift
import SwiftUI
import DesignSystem
import Visuals
#if os(iOS)
import PhotosUI
#endif

/// Editable form layer painted over the card backdrop: `+ Add Photo` button,
/// name `TextField` pill, description `TextField` pill. All three left-aligned
/// at 8pt from the card edge, stacked vertically.
struct CreateFormOverlay: View {

    @Bindable var model: CreateRecordModel

    #if os(iOS)
    @State private var photoItem: PhotosPickerItem?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            addPhotoButton

            NamePill(model: model)

            DescriptionPill(model: model)
        }
        .padding(.leading, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var addPhotoButton: some View {
        #if os(iOS)
        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
            Text("+ Add Photo")
                .font(CCDesign.Typography.caption2)
                .foregroundStyle(CCDesign.Colors.L0)
        }
        .accessibilityIdentifier("addPhotoButton")
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    model.photoData = data
                }
            }
        }
        #else
        Text("+ Add Photo")
            .font(CCDesign.Typography.caption2)
            .foregroundStyle(CCDesign.Colors.L0)
        #endif
    }
}

/// White/luminosity-blend pill carrying the name `TextField`. Cormorant SC
/// SemiBold 48. Placeholder uses SwiftUI's default secondary color — the
/// luminosity blend behind the pill produces the muted look Figma shows.
private struct NamePill: View {
    @Bindable var model: CreateRecordModel

    var body: some View {
        TextField("Name", text: $model.name)
            .font(.custom("CormorantSC-SemiBold", size: 48))
            .foregroundStyle(.black)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .frame(height: 60)
            .background(Color.white.opacity(0.56))
            .accessibilityIdentifier("nameField")
            .fixedSize(horizontal: true, vertical: false)
    }
}

/// Glass-blur pill carrying the description `TextField`. Cormorant Infant
/// SemiBold 18. Uses the same `BackdropBlurPill`-style visual as the card's
/// description pills but here we render a simpler border+fill combo since
/// this pill sits over the editable form stack, not the card text layer.
private struct DescriptionPill: View {
    @Bindable var model: CreateRecordModel

    var body: some View {
        TextField("Description", text: $model.description, axis: .horizontal)
            .font(CCDesign.Typography.description)
            .tracking(CCDesign.Typography.Tracking.description)
            .foregroundStyle(CCDesign.Colors.L0)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.15))
            .overlay(
                Rectangle()
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .accessibilityIdentifier("descriptionField")
            .fixedSize(horizontal: true, vertical: false)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages && swift test --filter FeatureCreateTests.CreateFormOverlayTests -q 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/FeatureCreate/CreateFormOverlay.swift Packages/Tests/FeatureCreateTests/CreateFormOverlayTests.swift
git commit -m "feat(create): add CreateFormOverlay with inline PhotosPicker"
```

---

## Task 9 — `LocationTimeStrip` + formatter tests

**Files:**
- Create: `Packages/Sources/FeatureCreate/LocationTimeStrip.swift`
- Test: `Packages/Tests/FeatureCreateTests/LocationTimeStripTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Packages/Tests/FeatureCreateTests/LocationTimeStripTests.swift`:

```swift
import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import FeatureCreate

@Suite struct LocationTimeStripTests {

    // 2020-08-25 17:20 UTC (matches Figma's 5:20 pm example in PDT if TZ is en_US/PDT;
    // keep assertions timezone-independent by forcing UTC).
    private let sampleDate = Date(timeIntervalSince1970: 1_598_376_000)

    @Test func formatsDateAsMMMdYYYY() {
        let formatted = LocationTimeStrip.formattedDate(sampleDate, timeZone: TimeZone(identifier: "UTC")!)
        #expect(formatted == "Aug 25, 2020")
    }

    @Test func formatsTimeWithLowercaseAmPm() {
        let formatted = LocationTimeStrip.formattedTimeLine(
            sampleDate,
            timeOfDay: .sunset,
            timeZone: TimeZone(identifier: "UTC")!
        )
        #expect(formatted == "Sunset, 5:20 pm")
    }

    @Test func timeLineCapitalizesTimeOfDay() {
        let formatted = LocationTimeStrip.formattedTimeLine(
            sampleDate,
            timeOfDay: .midday,
            timeZone: TimeZone(identifier: "UTC")!
        )
        #expect(formatted == "Midday, 5:20 pm")
    }

    @Test func splitsAddressAtFirstComma() {
        let (line1, line2) = LocationTimeStrip.splitAddress("1200 Treat Ave, San Francisco")
        #expect(line1 == "1200 TREAT AVE,")
        #expect(line2 == "SAN FRANCISCO")
    }

    @Test func splitAddressHandlesSingleLine() {
        let (line1, line2) = LocationTimeStrip.splitAddress("Downtown")
        #expect(line1 == "DOWNTOWN")
        #expect(line2 == "")
    }

    @Test func splitAddressHandlesEmpty() {
        let (line1, line2) = LocationTimeStrip.splitAddress(nil)
        #expect(line1 == "")
        #expect(line2 == "")
    }

    @MainActor @Test func viewInstantiatesWithLocation() {
        _ = LocationTimeStrip(
            location: LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 Treat Ave, San Francisco"),
            createdAt: sampleDate,
            timeOfDay: .sunset
        ).body
    }

    @MainActor @Test func viewInstantiatesWithoutLocation() {
        _ = LocationTimeStrip(location: nil, createdAt: sampleDate, timeOfDay: .midday).body
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd Packages && swift test --filter FeatureCreateTests.LocationTimeStripTests -q 2>&1 | tail -30`
Expected: FAIL with "cannot find 'LocationTimeStrip' in scope".

- [ ] **Step 3: Create the view + formatters**

Create `Packages/Sources/FeatureCreate/LocationTimeStrip.swift`:

```swift
import SwiftUI
import Foundation
import CoreModels
import DesignSystem

/// 40pt glass strip under the card. Left half: two-line uppercase address +
/// hologram-masked pin glyph. Right half: two-line date + `{timeOfDay}, h:mm a`.
/// Center vertical hairline separator.
struct LocationTimeStrip: View {

    let location: LocationInfo?
    let createdAt: Date
    let timeOfDay: TimeOfDay

    var body: some View {
        let (addrLine1, addrLine2) = Self.splitAddress(location?.label)
        let zone = TimeZone.current

        HStack(spacing: 0) {
            // Left half — address + pin.
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(addrLine1)
                    if !addrLine2.isEmpty {
                        Text(addrLine2)
                    }
                }
                .font(CCDesign.Typography.caption1)
                .tracking(CCDesign.Typography.Tracking.caption1)
                .foregroundStyle(CCDesign.Colors.L0)

                Spacer(minLength: 0)

                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(CCDesign.Colors.L0)
                    .opacity(0.75)
                    .padding(.trailing, 8)
            }
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            // Vertical hairline separator.
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 1, height: 38)

            // Right half — date + time.
            VStack(alignment: .trailing, spacing: 0) {
                Text(Self.formattedDate(createdAt, timeZone: zone))
                Text(Self.formattedTimeLine(createdAt, timeOfDay: timeOfDay, timeZone: zone))
            }
            .font(CCDesign.Typography.caption2)
            .foregroundStyle(CCDesign.Colors.L0)
            .padding(.top, 7)
            .padding(.trailing, 15)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(height: 40)
        .background(Color.white.opacity(0.1))
        .overlay(
            Rectangle().stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 8)
    }

    // MARK: - Formatters

    static func formattedDate(_ date: Date, timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    static func formattedTimeLine(_ date: Date, timeOfDay: TimeOfDay, timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        let time = f.string(from: date)
        let label = timeOfDay.rawValue.capitalized
        return "\(label), \(time)"
    }

    static func splitAddress(_ raw: String?) -> (String, String) {
        guard let raw, !raw.isEmpty else { return ("", "") }
        let upper = raw.uppercased()
        guard let commaRange = upper.range(of: ",") else {
            return (upper, "")
        }
        let line1 = String(upper[..<commaRange.upperBound])
        let line2 = String(upper[commaRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        return (line1, line2)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Packages && swift test --filter FeatureCreateTests.LocationTimeStripTests -q 2>&1 | tail -30`
Expected: PASS — all 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/FeatureCreate/LocationTimeStrip.swift Packages/Tests/FeatureCreateTests/LocationTimeStripTests.swift
git commit -m "feat(create): add LocationTimeStrip with date/time formatters"
```

---

## Task 10 — `SaveButton`

**Files:**
- Create: `Packages/Sources/FeatureCreate/SaveButton.swift`
- Test: `Packages/Tests/FeatureCreateTests/SaveButtonTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/Tests/FeatureCreateTests/SaveButtonTests.swift`:

```swift
import Testing
import SwiftUI
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct SaveButtonTests {

    @Test func instantiatesEnabled() {
        var tapped = 0
        let button = SaveButton(
            isEnabled: true,
            timeOfDay: .midday,
            attitude: .zero,
            action: { tapped += 1 }
        )
        _ = button.body
        button.action()
        #expect(tapped == 1)
    }

    @Test func instantiatesDisabled() {
        _ = SaveButton(
            isEnabled: false,
            timeOfDay: .night,
            attitude: .zero,
            action: {}
        ).body
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages && swift test --filter FeatureCreateTests.SaveButtonTests -q 2>&1 | tail -20`
Expected: FAIL.

- [ ] **Step 3: Create the view**

Create `Packages/Sources/FeatureCreate/SaveButton.swift`:

```swift
import SwiftUI
import CoreModels
import DesignSystem
import Visuals

/// Full-width SAVE button reusing the card's time-of-day gradient so it reads
/// as a continuation of the card above.
struct SaveButton: View {
    let isEnabled: Bool
    let timeOfDay: TimeOfDay
    let attitude: DeviceAttitude
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                GradientLayer(timeOfDay: timeOfDay, attitude: attitude)

                Text("SAVE")
                    .font(CCDesign.Typography.headline)
                    .tracking(CCDesign.Typography.Tracking.headline)
                    .foregroundStyle(CCDesign.Colors.L0)
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("saveRecordButton")
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd Packages && swift test --filter FeatureCreateTests.SaveButtonTests -q 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/FeatureCreate/SaveButton.swift Packages/Tests/FeatureCreateTests/SaveButtonTests.swift
git commit -m "feat(create): add SaveButton with time-of-day gradient"
```

---

## Task 11 — Rewrite `CreateRecordScene` & wire into `AppFeature`

This is the largest task — replace the scene body, delete `CreateFormFields.swift`, and update `RootScene` to supply `createdAt`/`metadata`/`location`.

**Files:**
- Modify: `Packages/Sources/FeatureCreate/CreateRecordScene.swift`
- Delete: `Packages/Sources/FeatureCreate/CreateFormFields.swift`
- Modify: `Packages/Sources/AppFeature/RootScene.swift`
- Modify: `Packages/Package.swift` (add `Visuals` as `FeatureCreateTests` dependency)
- Test: `Packages/Tests/FeatureCreateTests/CreateRecordSceneTests.swift`

- [ ] **Step 1a: Add `Visuals` to `FeatureCreateTests` dependencies**

The scene test needs `CardPathProvider`, `GuillocheShape`, and `CCVisuals.Guilloche.LineDensity` from `Visuals` to build a stub provider. Update the `FeatureCreateTests` test target in `Packages/Package.swift`:

```swift
.testTarget(
    name: "FeatureCreateTests",
    dependencies: ["FeatureCreate", "CoreModels", "Visuals"],
    path: "Tests/FeatureCreateTests"
),
```

- [ ] **Step 1b: Write the failing scene test**

Create `Packages/Tests/FeatureCreateTests/CreateRecordSceneTests.swift`:

```swift
import Testing
import SwiftUI
import Foundation
import CoreModels
import Visuals
@testable import FeatureCreate

@MainActor
@Suite struct CreateRecordSceneTests {

    private struct StubPaths: CardPathProvider {
        func rotationPaths(for letter: Character) -> [Path] { [] }
        func blendPaths(for letter: Character, shape: GuillocheShape, density: CCVisuals.Guilloche.LineDensity) -> [Path] { [] }
    }

    private let fixedDate = Date(timeIntervalSince1970: 1_598_376_000)
    private let metadata = RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
    private let location = LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 Treat Ave, San Francisco")

    @Test func sceneInstantiatesWithAllInputs() {
        _ = CreateRecordScene(
            attitude: .zero,
            paths: StubPaths(),
            createdAt: fixedDate,
            metadata: metadata,
            location: location,
            onCancel: {},
            onSave: { _ in }
        ).body
    }

    @Test func sceneInstantiatesWithoutLocation() {
        _ = CreateRecordScene(
            attitude: .zero,
            paths: StubPaths(),
            createdAt: fixedDate,
            metadata: metadata,
            location: nil,
            onCancel: {},
            onSave: { _ in }
        ).body
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Packages && swift test --filter FeatureCreateTests.CreateRecordSceneTests -q 2>&1 | tail -20`
Expected: FAIL with "missing arguments for parameters 'createdAt', 'metadata', 'location'".

- [ ] **Step 3: Rewrite `CreateRecordScene.swift`**

Replace the entire contents of `Packages/Sources/FeatureCreate/CreateRecordScene.swift` with:

```swift
import SwiftUI
import Foundation
import CoreModels
import DesignSystem
import Visuals

public struct CreateRecordScene: View {

    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let onCancel: () -> Void
    public let onSave: (RecordDraft) -> Void

    @State private var model: CreateRecordModel

    public init(
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        createdAt: Date,
        metadata: RecordMetadata,
        location: LocationInfo?,
        onCancel: @escaping () -> Void,
        onSave: @escaping (RecordDraft) -> Void
    ) {
        self.attitude = attitude
        self.paths = paths
        self.onCancel = onCancel
        self.onSave = onSave
        _model = State(initialValue: CreateRecordModel(
            createdAt: createdAt,
            metadata: metadata,
            location: location
        ))
    }

    public var body: some View {
        VStack(spacing: 0) {
            PersonTopNav(onCancel: onCancel)

            cardArea
                .frame(height: 467)

            LocationTimeStrip(
                location: model.location,
                createdAt: model.createdAt,
                timeOfDay: model.metadata.timeOfDay
            )

            SaveButton(
                isEnabled: model.isSaveable,
                timeOfDay: model.metadata.timeOfDay,
                attitude: attitude,
                action: { onSave(model.draft) }
            )

            Spacer(minLength: 0)
        }
        .background(CCDesign.Colors.L2)
    }

    @ViewBuilder
    private var cardArea: some View {
        ZStack(alignment: .topTrailing) {
            CardBackdrop(
                record: model.previewRecord,
                attitude: attitude,
                paths: paths,
                photo: photoImage
            )

            // Right-edge zodiac bundle — 100×127 frame positioned per Figma
            // (frame origin x=275, y=259 relative to card at 375×467).
            ZStack(alignment: .topLeading) {
                CreateConstellationBadge(sign: model.randomZodiacSign, attitude: attitude)
                    .frame(width: 100, height: 90)

                CreateZodiacSymbolBadge(sign: model.randomZodiacSign, attitude: attitude)
                    .frame(width: 35, height: 32)
                    .offset(x: 52, y: 70)

                CreateMoonPhaseBadge(phase: model.metadata.moonPhase)
                    .frame(width: 35, height: 56)
                    .offset(x: 57, y: 71)
            }
            .frame(width: 100, height: 127)
            .offset(y: 259)

            // Editable form layer — top-leading anchor, 8pt leading inset
            // handled by the overlay itself.
            CreateFormOverlay(model: model)
        }
        .clipped()
    }

    private var photoImage: Image? {
        #if canImport(UIKit)
        guard let data = model.photoData, let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }
}
```

- [ ] **Step 4: Delete `CreateFormFields.swift`**

```bash
git rm Packages/Sources/FeatureCreate/CreateFormFields.swift
```

- [ ] **Step 5: Update `RootScene` to pass new parameters**

In `Packages/Sources/AppFeature/RootScene.swift`, replace the `.sheet(isPresented: $router.showingCreate)` block with:

```swift
.sheet(isPresented: $router.showingCreate) {
    let createdAt = Date()
    let metadata = environment.metadataGenerator.metadata(at: createdAt, location: nil)
    CreateRecordScene(
        attitude: currentAttitude,
        paths: environment.cardPathProvider,
        createdAt: createdAt,
        metadata: metadata,
        location: nil,  // LocationService wiring deferred; scene renders strip without left-half content
        onCancel: { router.showingCreate = false },
        onSave: { draft in
            Task {
                let saveMetadata = environment.metadataGenerator.metadata(
                    at: Date(),
                    location: draft.location
                )
                _ = try? await environment.recordStore.create(draft, metadata: saveMetadata)
                router.showingCreate = false
            }
        }
    )
}
```

- [ ] **Step 6: Run all tests to verify everything passes**

Run: `cd Packages && swift test -q 2>&1 | tail -40`
Expected: PASS — ~140+ tests pass across all suites.

- [ ] **Step 7: Build the app on the simulator and visually verify the screen**

Run:
```bash
cd /Users/adam/Projects/casual-contacts-contact-create-ui-fixes
xcodebuild build \
    -scheme CasualContacts \
    -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20

xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install "iPhone 17" \
    /Users/adam/Projects/casual-contacts-contact-create-ui-fixes/CasualContacts/build/Debug-iphonesimulator/CasualContacts.app
xcrun simctl launch "iPhone 17" com.stacksdubeurre.CasualContacts
```

Expected: build succeeds. Tap `+` to open the create sheet. Visually compare with Figma node `185:8911`:
- Top nav: Cancel / PERSON / + Person (disabled)
- Card atmosphere renders with gradient + guilloche
- Random zodiac badges visible on right edge
- Name and description pills editable; keyboard appears on tap
- Location strip shows date/time only (location nil)
- SAVE disabled until name non-empty

- [ ] **Step 8: Screenshot the simulator and save for comparison**

Run:
```bash
xcrun simctl io "iPhone 17" screenshot /tmp/create-scene-sim.png
```

Open `/tmp/create-scene-sim.png` in Preview. Compare side-by-side with the Figma screenshot fetched during brainstorming. Any pixel-level divergence that would violate CLAUDE.md §"Design fidelity directives" is a stop sign — flag and discuss before proceeding.

- [ ] **Step 9: Commit**

```bash
git add Packages/Sources/FeatureCreate/CreateRecordScene.swift Packages/Sources/AppFeature/RootScene.swift Packages/Tests/FeatureCreateTests/CreateRecordSceneTests.swift
git rm Packages/Sources/FeatureCreate/CreateFormFields.swift
git commit -m "feat(create): rewrite CreateRecordScene to match Figma L_Add_new_Name_1P"
```

---

## Task 12 — Verification sweep

**Files:** None to edit. Run-only.

- [ ] **Step 1: Host-side suite**

Run: `cd Packages && swift test 2>&1 | tail -20`
Expected: All ~140 tests pass.

- [ ] **Step 2: Simulator-gated tests**

Run:
```bash
cd Packages
xcodebuild test \
    -scheme CasualContactsPackages-Package \
    -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```
Expected: All tests pass, including `CardSnapshotTests` (regression gate for Task 1) and `AppEnvironmentTests.production()`.

- [ ] **Step 3: Release-mode build**

Run:
```bash
cd /Users/adam/Projects/casual-contacts-contact-create-ui-fixes
xcodebuild build \
    -scheme CasualContacts \
    -configuration Release \
    -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -10
```
Expected: Release build succeeds (catches any `#if DEBUG`-only assumptions).

- [ ] **Step 4: If any step fails, fix and commit before proceeding**

If any verification fails, stop and investigate. Root-cause, don't paper over. Commit the fix(es) as focused follow-up commits.

---

## Out of scope for this plan

These are noted in the spec and intentionally **not** touched here:

- **Zodiac picker wiring** — `ZodiacPickerSheet.swift` stays unused; future plan picks a trigger (tap the badge area vs. a dedicated button vs. derived-from-birthday).
- **2-person flow** — `+ Person` is a disabled placeholder. Visual parity only.
- **LocationService wiring in `RootScene`** — `location` is passed as `nil` today; a future small change will hook up the existing `CoreLocationService` to resolve a label and pass it in.
- **Dynamic Type / Reduce Motion polish** — Plan 3.1 T10/T11 own those.
- **XCUITest coverage** — Plan 3.1 T13.
- **Snapshot tests for the new scene** — deliberate: the Figma target is complex (fonts, gradients, blend modes) and snapshot tests at this stage would churn on every minor visual refinement. If/when the screen stabilizes we can add `CreateSceneSnapshotTests` analogous to `CardSnapshotTests`.

---

## Self-review

**Spec coverage (§ by § against the design spec):**
- §3 Non-goals: deferred items called out in "Out of scope" + tasks do not wire them.
- §4.1 `CardBackdrop` extraction — Task 1.
- §4.2 Feature module file layout — all files created in Tasks 4–11.
- §4.3 Create-flow zodiac badges as three sibling views — Tasks 4, 5, 6.
- §5 Screen composition — Task 11 Step 3 matches.
- §6.1 Model changes — Task 3.
- §6.2 Scene signature — Task 11 Step 3 matches new init shape.
- §6.3 Photo flow — Task 8 via inline `PhotosPicker`.
- §6.4 Save flow — Task 11 Step 5 preserves existing `onSave` shape.
- §7.1 `PersonTopNav` tokens — Task 7.
- §7.2 Form overlay tokens + placeholder styling — Task 8.
- §7.3 Zodiac badges — Tasks 4–6.
- §7.4 `LocationTimeStrip` — Task 9.
- §7.5 `SaveButton` — Task 10.
- §7.6 Sheet chrome — Task 11 (uses default `.sheet`).
- §8 Testing — each task has its own tests; verification sweep in Task 12.
- §9 `CCVisuals.bundle` accessor — Task 2.

**Type/method consistency:**
- `CreateRecordModel(createdAt:metadata:location:randomZodiacSign:)` used identically across Tasks 3, 8, 9, 11.
- `CardBackdrop(record:attitude:paths:photo:)` used identically in Tasks 1 and 11.
- `CCVisuals.bundle` used identically in Tasks 4, 5, 6.
- `PersonTopNav(onCancel:)`, `CreateFormOverlay(model:)`, `LocationTimeStrip(location:createdAt:timeOfDay:)`, `SaveButton(isEnabled:timeOfDay:attitude:action:)` — all consistent between their defining tasks and Task 11's composition.
- Moon phase asset typo mapping matches `MoonPhaseLayer.assetName(for:)` (Task 6 mirrors the existing private mapping).

**Placeholder scan:** no TBDs, no "add error handling", no "similar to Task N" references without repeating the code.
