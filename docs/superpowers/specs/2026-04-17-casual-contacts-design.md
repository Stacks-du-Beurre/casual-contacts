# Casual Contacts — Design Spec

**Date:** 2026-04-17
**Status:** Approved for implementation planning
**Scope:** v1 (Phase 1 — MVP core + Phase 2 — Visual identity)

---

## 1. Overview & Scope

### What it is
A native iOS app for quickly recording people you've just met in casual settings — cafés, parties, concerts — where you might only have a first name and a short association. The app auto-captures ambient metadata (time, time-of-day label, moon phase, optional location) and derives a unique visual "card" from that metadata to reinforce memory through mental association.

### Target
- iOS 18+, iPhone only, portrait
- Light and Dark mode
- SwiftUI, SwiftData, Swift 6 strict concurrency
- Fully local (no server, no network calls in v1)

### Core user loop
1. Open app → tap "+" → type a name + short description → card generates live as you type → Save.
2. Later: open app → find person by scrolling or searching → tap for medium card → optionally expand to fullscreen.

### v1 scope (Phase 1 + Phase 2)
**In:**
- Create / edit / delete record (Name*, Description, optional Photo, optional Location, optional Zodiac)
- Live preview card in Create flow
- Auto-metadata at creation: date/time, time-of-day category, moon phase
- Searchable basic-collection-view list, empty state
- Medium modal + Large fullscreen detail views
- About / Settings screen
- Generated card visuals: gradient background, guilloche rotation background, letter-blend foreground (letter → Circle/Square/Polygon), moon phase glyph, zodiac glyph (when set), holographic text / location / zodiac effects
- Gyroscope-driven animations across all visible cards
- Haptics, Dynamic Type, VoiceOver, Light/Dark Mode, Reduce Motion / Reduce Transparency / Increase Contrast support

**Deferred (v1.1+):**
- Recommended section (location-based retrieval)
- Default + Advanced sorting screens
- 2-person add flow
- iCloud sync
- Advanced Card Stack list layout
- Phone / email fields (revisit based on post-launch feedback)

### Naming
- App name / App Store: **Casual Contacts**
- List screen title: **MY CONTACTS** (per design spec)
- Bundle ID (proposed): `com.stacksdubeurre.casualcontacts` (confirm before TestFlight)

---

## 2. Architecture

### Pattern: MV (Model-View) + protocol-backed services
- No ViewModels. Business logic lives in `@Observable` service classes injected via `.environment`.
- Features observe services directly via `@Environment`.
- Services expose protocols; features depend on protocols only.
- Concrete implementations live in Storage / Services modules; the `AppFeature` / app target is the only place that sees concrete types and wires them up.

### Module graph (local Swift Package, compiler-enforced boundaries)

```
App Target (thin shell, ~20 LOC)
      │
      └── AppFeature           ← composes everything, injects concrete impls
              │
     ┌────────┼──────────┬──────────┬──────────┐
FeatureList  FeatureCreate  FeatureDetail  FeatureSettings
     │        │         │         │
     └────────┴────┬────┴─────────┘
                  ▼
        Visuals  +  DesignSystem
                  │
                  ▼
              CoreModels       ← protocols + plain types, zero deps
                  ▲
        ┌─────────┴─────────┐
     Storage              Services
  (SwiftData impl)   (CoreLocation, CoreMotion, Metadata impls)
```

### Boundary rules (enforced by Swift Package target dependencies)
- Features depend on `CoreModels` (protocols) only — never `Storage` or `Services` directly.
- `Storage`, `Services` implement protocols from `CoreModels`.
- `Visuals` depends on `CoreModels` + `DesignSystem`; no Feature, Storage, or Services imports.
- `DesignSystem` is framework-free apart from SwiftUI.
- `AppFeature` is the only module that wires concrete implementations into `.environment(...)`.
- Each module has its own test target.

### Concurrency
- Services and stores are `@MainActor @Observable` classes by default.
- Protocol types carry `Sendable` constraints where they cross actor boundaries.
- Heavy work (visual path codegen is build-time; moon-phase math, motion smoothing) uses non-isolated pure functions returning `Sendable` values.
- Swift 6 strict concurrency on the whole package.

### Navigation
- `NavigationStack` with value-based routing (`NavigationPath` + `.navigationDestination(for:)`).
- Create: `sheet(isPresented:).presentationDetents([.large])`, fullscreen.
- Detail Medium: `sheet().presentationDetents([.medium])`.
- Detail Large: fullscreen push from Medium, or alternative presentation — final choice during implementation.
- Settings: `sheet().presentationDetents([.medium])` from the list's top-bar menu.

### Dependency injection
- SwiftUI `@Environment` + `@Entry` macro for typed environment keys.
- Default values for environment entries are `Unimplemented…` types that fail loudly if a module forgets to inject — catches missing wiring during previews.

---

## 3. Data Model

### Principles
- **Metadata snapshot at creation** — `createdAt`, `timeOfDay`, `moonPhase` are captured once and never recomputed. That's the whole point: the record is a moment.
- **Visual accoutrements are derived on the fly** from stable fields (`id`, `createdAt`, `name`). Cheap to compute; lets us refine the algorithm without migration.
- **Photos on disk, not in DB** — `Documents/Photos/<UUID>.heic` with only the filename stored. Keeps DB small for eventual iCloud sync.
- **Zodiac is user-editable** and optional — often learned after the initial meeting.

### CoreModels — pure Swift types (zero framework deps)

```swift
public struct Record: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var photoID: PhotoID?
    public var location: LocationInfo?
    public var zodiacSign: ZodiacSign?         // user-editable, optional
    public let createdAt: Date
    public var updatedAt: Date
    public let metadata: RecordMetadata        // captured at creation, immutable
}

public struct RecordMetadata: Hashable, Sendable {
    public let timeOfDay: TimeOfDay            // from createdAt + location (sun calc)
    public let moonPhase: MoonPhase            // from createdAt (astronomical calc)
}

public enum TimeOfDay: String, CaseIterable, Sendable {
    case dawn, sunrise, midday, sunset, dusk, night, midnight
}

public enum MoonPhase: String, CaseIterable, Sendable {
    case newMoon, waxingCrescent, firstQuarter, waxingGibbous,
         fullMoon, waningGibbous, thirdQuarter, waningCrescent
}

public enum ZodiacSign: String, CaseIterable, Sendable {
    case aries, taurus, gemini, cancer, leo, virgo,
         libra, scorpio, sagittarius, capricorn, aquarius, pisces
}

public struct LocationInfo: Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let label: String?                  // reverse-geocoded, optional
}

public struct PhotoID: Hashable, Sendable {
    public let filename: String                // UUID.heic
}
```

### Derived visual accoutrements (computed, not stored)

```swift
public struct VisualAccoutrements: Hashable, Sendable {
    public let palette: ColorPalette            // from timeOfDay
    public let letter: Character                // first letter of name, uppercased A–Z
    public let guillocheShape: GuillocheShape   // Circle / Square / Polygon
}

public enum GuillocheShape: String, CaseIterable, Sendable {
    case circle, square, polygon
}

public extension Record {
    var accoutrements: VisualAccoutrements {
        VisualAccoutrements(
            palette: ColorPalette(for: metadata.timeOfDay),
            letter: name.first.map { Character($0.uppercased()) } ?? "A",
            guillocheShape: GuillocheShape.allCases[abs(id.hashValue) % 3]
        )
    }
}
```

### Draft type (input to create flow)

```swift
public struct RecordDraft: Sendable {
    public var name: String
    public var description: String
    public var photo: Data?                    // stored via PhotoStore at commit
    public var location: LocationInfo?
    public var zodiacSign: ZodiacSign?
    // createdAt is stamped by RecordStore.create
    // metadata is computed at create time from createdAt + location
}
```

### Protocols (services the app depends on)

```swift
public protocol RecordStore: AnyObject, Sendable {
    var records: [Record] { get }                         // observable at impl
    func create(_ draft: RecordDraft) async throws -> Record
    func update(_ record: Record) async throws
    func delete(id: Record.ID) async throws
    func search(_ query: String) -> [Record]
}

public protocol PhotoStore: Sendable {
    func save(_ data: Data) async throws -> PhotoID
    func load(_ id: PhotoID) async throws -> Data?
    func delete(_ id: PhotoID) async throws
}

public protocol LocationService: AnyObject, Sendable {
    func requestAuthorization() async -> LocationAuthorization
    func currentLocation() async throws -> LocationInfo?
}

public protocol MotionService: AnyObject, Sendable {
    var attitude: AsyncStream<DeviceAttitude> { get }
    func start()
    func stop()
}

public protocol MetadataGenerator: Sendable {
    func metadata(at date: Date, location: LocationInfo?) -> RecordMetadata
}

public struct DeviceAttitude: Sendable {
    public let pitch: Double    // -1.0 … 1.0, smoothed
    public let roll: Double     // -1.0 … 1.0, smoothed
}

public enum LocationAuthorization: Sendable {
    case authorized, denied, notDetermined
}
```

### Concrete implementations (per module)

| Protocol | Real impl (Storage / Services) | Fake (TestSupport) |
|---|---|---|
| `RecordStore` | `SwiftDataRecordStore` | `InMemoryRecordStore` |
| `PhotoStore` | `FileSystemPhotoStore` | `InMemoryPhotoStore` |
| `LocationService` | `CoreLocationService` | `MockLocationService` |
| `MotionService` | `CoreMotionService` | `StaticMotionService` |
| `MetadataGenerator` | `SystemMetadataGenerator` | `FixedMetadataGenerator` |

### Persistence (Storage module)

```swift
@Model
public final class PersistedRecord {
    public var id: UUID
    public var name: String
    public var recordDescription: String       // `description` is reserved on NSObject-bridged types
    public var photoFilename: String?
    public var latitude: Double?
    public var longitude: Double?
    public var locationLabel: String?
    public var zodiacSignRaw: String?          // nil when unset
    public var createdAt: Date
    public var updatedAt: Date
    public var timeOfDayRaw: String
    public var moonPhaseRaw: String
    // mapping to/from Record lives in SwiftDataRecordStore
}
```

`PersistedRecord` stays private to the `Storage` module. Features see only the plain `Record` struct.

---

## 4. Screens & Flows

### Navigation tree

```
Root: RecordsList (FeatureList)
  ├── "+" button  → sheet(.fullScreen): CreateRecord (FeatureCreate)
  ├── tap record  → sheet(.medium): DetailMedium   (FeatureDetail)
  │                     └── "Expand" → fullscreen: DetailLarge (edit-capable)
  └── top-bar menu → sheet(.medium): Settings / About (FeatureSettings)
```

### 4.1 RecordsList (home)
- Top bar: "MY CONTACTS" title, search field (filters by name), settings icon
- Body: scrollable list of small cards, newest first (flat reverse-chronological in v1)
- Empty state: sunset gradient + polygon glyph (per Figma `L_Collection_View_Empty`) + "No one here yet" + persistent "+" button
- Floating "+" button bottom-right
- Recommended section: **hidden in v1**; layout reserves the slot so turning it on in Phase 3 is additive

### 4.2 CreateRecord (`sheet(.fullScreen)`)
- Header: Cancel (left), "Person" title (center), Save (right — disabled until `name` is non-empty)
- **Live preview card** fills ~55% of screen, edge-to-edge, updates as user types
- Below the card: scrollable form fields — Name, Description, Photo button, Location row (auto-fills with current location if permission granted; tappable to edit/remove), Zodiac row (empty by default, tappable → picker)
- Keyboard always present
- On Save: write record via `RecordStore.create`, dismiss sheet, new record animates to top of list with a success haptic

### 4.3 DetailMedium (`sheet(.medium)`)
- Non-editable medium-size card with all visual layers, gyroscope-active
- Shows: name, description, photo (if present), location label, time-of-day + moon glyphs, zodiac glyph (if set)
- Footer: "Expand", "Edit", "Delete" buttons; drag handle for swipe-dismiss

### 4.4 DetailLarge (fullscreen, edit-capable)
- Full-bleed version of the card, edge-to-edge, gyroscope-driven
- Same info as Medium, typography scaled up
- Tapping "Edit" reveals form fields in place over a dimmed card; Save / Cancel in top bar
- Delete surfaces as destructive action with confirmation

### 4.5 Settings (`sheet(.medium)`)
- Matches Figma `Context_Menu`: bottom sheet, "Settings" header
- Rows:
  - **Sync data with iCloud** (toggle) — disabled in v1, "Coming soon"
  - **Turn on advanced card stack** (toggle) — disabled in v1, "Coming soon"
  - **Rate on the App Store** — opens App Store review prompt
  - **Recommended Casual Contacts** — opens a share card (v1: routes to "About")
  - **About developers** — pushes a plain view with contact info + version + acknowledgments
- Footer: "Casual Contacts Version X.Y" label

### Flow scripts (happy paths)

**First launch**
Splash (~1s) → RecordsList empty state → tap "+" → location permission prompt (first time only) → form with preview card → Save → new record at top of list.

**Add a record**
RecordsList → "+" → type name (card updates with guilloche derived from name) → type description → (optional) add photo / adjust location → Save → record appears.

**Recall**
RecordsList → search "Jane" → tap result → Medium detail → read → dismiss.

**Edit zodiac later**
RecordsList → tap record → Medium detail → Expand → Edit → pick zodiac → Save.

### Permissions
- **Location:** requested on first Create-screen open, not at app launch. Usage string: "Casual Contacts tags where you met someone, so you can find them again."
- **Camera:** requested on first Photo tap in Create, if user chooses "Take Photo".
- **Photo Library:** requested on first Photo tap in Create, if user chooses "Choose Photo".
- **Motion:** no runtime permission required (CoreMotion device motion is permission-free).

---

## 5. Visual System

All visual rendering lives in the `Visuals` module, which depends only on `CoreModels` and `DesignSystem`. Consumed by Feature modules as composable SwiftUI views driven by `VisualAccoutrements` + live `DeviceAttitude`.

### 5.1 Layer model

Every card is the same layered stack, composed differently per size:

```
┌─────────────────────────────────────────┐
│ 7. Foreground holograms                 │  title, location, zodiac — blend-mode stacks
│ 6. Moon phase glyph                     │
│ 5. Zodiac constellation (if set)        │  user-editable
│ 4. Photo OR guilloche letter-blend      │  photo replaces letter-blend when present
│ 3. Guilloche rotation (background)      │  letter-rotated radial pattern, subtle
│ 2. Gradient transfusion (top layer)     │  stacked, opacity driven by gyro
│ 1. Time-of-day base gradient            │
└─────────────────────────────────────────┘
```

Card-size variants:

| Layer | Small (list) | Medium (modal) | Large (fullscreen) |
|---|---|---|---|
| 1. Base gradient | ✓ | ✓ | ✓ |
| 2. Transfusion overlay | ✓ (live) | ✓ (live) | ✓ (live) |
| 3. Guilloche rotation bg | ✓ | ✓ | ✓ |
| 4. Photo / Letter-blend | ✓ (Preview variant, 7 lines) | ✓ (full 15 lines) | ✓ (full 15 lines) |
| 5. Zodiac | optional | ✓ | ✓ |
| 6. Moon phase | ✓ | ✓ | ✓ |
| 7. Holograms (blend-modes) | ✓ (live) | ✓ (live) | ✓ (live) |

All visible cards receive live `DeviceAttitude` updates; no "static preview" reduction except when Reduce Motion is enabled.

### 5.2 Gyroscope input model

One shared `MotionService` provides a `DeviceAttitude` stream (`pitch`, `roll`) clamped and smoothed:

- One `CMMotionManager` instance in the whole app, owned by `CoreMotionService`.
- Started when any card view appears, stopped when all disappear (ref-count).
- Smoothing: low-pass filter (α ≈ 0.1) against jitter.
- `StaticMotionService` returns `.zero` — used for previews, snapshot tests, Reduce Motion.
- Respects `UIAccessibility.isReduceMotionEnabled` — live service publishes `.zero` when on.

Each visual effect owns its own mapping from attitude to visual parameter. Examples:
- Transfusion opacity: `topOpacity = (roll + 1) / 2`
- Holographic title: bottom-layer offset `(pitch * 8, roll * 8)`; top-layer rotation `roll * 3°`
- Letter-blend parallax: ring `i` of 15 → offset `(roll * (i+1), pitch * (i+1))`

### 5.3 Gradient system

- Seven time-of-day palettes: Dawn, Sunrise, Midday, Sunset, Dusk, Night, Midnight
- **Rebuilt as native SwiftUI `LinearGradient`** — no PNGs shipped
- Color stops + angles sourced from Figma (see Section 9 open items — extraction deferred to implementation)
- Each palette exposed as:

```swift
public struct ColorPalette: Sendable {
    public let base: LinearGradient       // full-bleed background
    public let transfusionTop: LinearGradient  // stacked for the transfusion effect
}

public extension ColorPalette {
    init(for timeOfDay: TimeOfDay) { … }  // maps enum → palette
}
```

- **Transfusion** = two identical gradients in a `ZStack`, top layer's `.opacity(...)` driven by `DeviceAttitude.roll`.

### 5.4 Guilloche — Rotation (background layer)

- One SVG per letter (A–Z) in `design-assets/Rotation/`.
- Each SVG contains ~72 `<path>` elements — the letter outline rotated through 5° increments around a Bezier-spline pivot, forming a radial sunburst.
- **Build-time asset pipeline** (§5.11) parses each SVG, emits a static `[Path]` per letter.
- Rendered in a single `Canvas` pass; ~20% opacity so it reads as texture, not decoration.
- Gyroscope influence: **static in v1**. Design spec doesn't call out motion here; revisit in polish pass.

### 5.5 Guilloche — Blend (foreground letter layer)

- Per record: one SVG selected from `design-assets/Blended_export/SVG/<letter>_<shape>.svg`, where `letter = firstLetter(name).uppercased()` and `shape = GuillocheShape.allCases[abs(id.hashValue) % 3]`.
- Each SVG contains 15 `<path>` elements representing the 15 intermediate morph steps from letter → shape.
- Build-time pipeline emits `Blend.A.circle`, `Blend.A.square`, `Blend.A.polygon`, etc. — each a `[Path]` of 15 values.

**"Deep dive" parallax animation:**
All 15 paths render stacked in the same frame. Each path `i` (0 = innermost letter outline, 14 = outermost container shape) gets a depth-scaled offset:

```
path[i].offset = (roll * (i + 1) * k, pitch * (i + 1) * k)
```

where `k` is a small constant (~0.5 pt). Held flat, paths coincide perfectly and the static blend is visible. Tilted, paths fan out proportional to depth — innermost barely shifts, outermost shifts most, creating a parallax illusion of a 3D wireframe ziggurat. This is the "deep dive effect" described in the design spec.

**Small (list) variant:** use the `_Preview.svg` per-letter file (7 lines instead of 15, single pre-chosen shape). Parallax still applied.

**Deferred-but-accommodated:** the Recommended Section (Phase 3) also uses 7-line density with a single shape type. The module API takes a `LineDensity` parameter — the Phase-3 turn-on is a switch flip at the call site, not a refactor.

### 5.6 Moon phase

- 8 SVGs in `design-assets/Moon_Phases/` + `Moon_Background.svg`
- Exposed as `Image("moon/<phase>")` through the `DesignSystem` asset catalog
- No gyroscope reactivity — too small to read the motion
- Source filenames contain typos (e.g., `Waning_Crescennt.svg`) — preserved as-is in assets to avoid rename drift; clean `MoonPhase` enum abstracts them

### 5.7 Zodiac

- 12 signs, two treatments: constellation line art (`Zodiac/Сonstellations/`, Cyrillic C preserved) and figurative illustration (`Zodiac/Signs/`)
- Card layer uses the figurative illustration
- Subtle gyroscope-driven x/y translation applied
- Absent when `record.zodiacSign == nil`

### 5.8 Holograms (text + location + zodiac effects)

Every card's textual/glyph elements render in a holographic blend-mode stack. Three SwiftUI views in `Visuals/Holographic/`:

```swift
public struct HolographicText: View {
    public let text: String
    public let attitude: DeviceAttitude
    // bottom layer: text.blendMode(.lighten).offset(roll*8, pitch*8)
    // top layer:    text.blendMode(.luminosity).rotationEffect(roll*3°)
}

public struct HolographicLocation: View {
    public let address: String
    public let attitude: DeviceAttitude
    // bottom layer additionally: .blur(radius: 2)
}

public struct HolographicZodiac: View {
    public let sign: ZodiacSign
    public let attitude: DeviceAttitude
    // image translates on (roll, pitch); no rotation
}
```

SwiftUI's native `.blendMode()` handles all of this — no Metal shaders required in v1.

### 5.9 Photo treatments

- **Card (List / Medium / Large):** `Image(...).blendMode(.luminosity).opacity(0.6)` over the gradient stack. Photo replaces the letter-blend layer when present; guilloche rotation background stays behind.
- **Recommended section (Phase 3, structured-in not rendered):** two stacked copies — bottom `.blendMode(.luminosity)`, top `.blendMode(.color)` — yields a "glitch" effect. Circular crop. Deferred but the composition view is designed to accept this mode.

### 5.10 Card composition views

Exported from `Visuals`:

```swift
public struct CardView: View {
    public let record: Record
    public let size: CardSize               // .small / .medium / .large
    public let attitude: DeviceAttitude     // from parent's MotionService
}

public enum CardSize { case small, medium, large }
```

`CardView` composes:

```swift
ZStack {
  GradientLayer(timeOfDay: ..., attitude: ...)
  GuillocheRotationLayer(letter: ..., attitude: ...)
  if let photo { PhotoLayer(...) } else { GuillocheBlendLayer(letter:, shape:, density:, attitude:) }
  if let sign { ZodiacLayer(sign:, attitude:) }
  MoonPhaseLayer(phase: ...)
  CardTextLayer(name:, description:, location:, date:, attitude:)
}
```

Each named layer is its own `View` in `Visuals/…` — independently previewable, independently snapshot-testable.

### 5.11 Asset pipeline — build-time SVG → Swift

A Swift executable at `Tools/SVGToSwift/`, wired as an **Xcode build phase** (or SwiftPM plugin) that runs before compilation:

1. Scans `design-assets/Rotation/*.svg` and `design-assets/Blended_export/SVG/*.svg`.
2. Parses each SVG, extracting every `<path d="...">` attribute.
3. Emits Swift files in `Visuals/Guilloche/Generated/` with typed `[Path]` values.

Example output:

```swift
// Generated/Blend_A_Circle.swift
public extension Blend {
    static let aCircle: [Path] = [
        Path { p in p.move(to: …); p.addCurve(…) /* ring 0 */ },
        Path { p in … /* ring 1 */ },
        // … 15 total
    ]
}
```

- SVGs remain the source of truth in `design-assets/`.
- Generated `.swift` files are `.gitignore`d — rebuilt on demand.
- The parser is lightweight (~200 LOC): it only handles the `d="…"` path-command subset these assets use (M, L, C, Q, Z, etc.), not full SVG rendering.
- Full preview support in Xcode because everything is real Swift code at compile time.

### 5.12 Accessibility & performance

**Accessibility-driven fallbacks:**
- `UIAccessibility.isReduceMotionEnabled` → `MotionService` publishes `.zero` permanently. Parallax, hologram rotations, transfusion opacity shifts → static.
- `UIAccessibility.isReduceTransparencyEnabled` → blend-mode stacks collapse to solid fills; photo luminosity opacity → 100%.
- `UIAccessibility.isDarkerSystemColorsEnabled` → holographic text becomes solid-color at full opacity; background guilloche opacity drops near zero.

**Performance targets** (iPhone 16 baseline, iPhone 13 minimum):
- List scroll: 60fps with all visible cards animating holograms + letter-blend
- App launch → RecordsList rendered: <400ms cold, <150ms warm
- Create screen → first preview card render: <100ms after name-field change
- Memory: <150MB resident with 500 records

**Scrolling budget:** `LazyVStack` only composites on-screen rows. Visible cards (~6–8 small at once) × 7 paths + 3 hologram stacks is well inside frame budget. Profile early with Instruments; optimize only if measurements demand it.

---

## 6. Testing Strategy

### Framework
Swift Testing (`@Test`, `#expect`). Swift 6 / iOS 18.

### Per-module test targets
Each Swift package target has a sibling `<Module>Tests` target. Running tests for one module compiles only that module + its dependencies.

### Testing pyramid

| Layer | What we test | How |
|---|---|---|
| **CoreModels** | Pure types — Codable, hashing, enum conversions, `VisualAccoutrements` derivation determinism | Plain unit tests, no mocking |
| **Storage** | `SwiftDataRecordStore` CRUD against in-memory `ModelContext`; `PersistedRecord ↔ Record` round-trip; concurrent writes | In-memory SwiftData config |
| **Services** | `SystemMetadataGenerator` moon-phase + time-of-day math against known dates; `CoreLocationService` via injected `CLLocationManagerProtocol` fake | No device required |
| **Visuals** | Generated `Path` output snapshot tests (SVG → Swift codegen is stable); layer composition structure | `swift-snapshot-testing` |
| **Features** | Views render against fake services; Create happy path; Edit preserves metadata; Delete removes from store | Fakes injected via `.environment` |
| **App (integration)** | End-to-end create → list → detail → edit → delete with real SwiftData + fake Location/Motion | One integration test target |

### Snapshot testing
`swift-snapshot-testing` (Point-Free) — the one third-party dependency in the project. Snapshots of each card / layer view at key attitudes (flat, max-pitch, max-roll) × three sizes. Regressions caught on first render change.

### UI tests
Minimal. One XCUITest suite covering five flows: first-launch permission prompt, create, search, edit, delete. UI tests are slow; keep the layer thin.

### Fakes, not mocks
Each protocol has an `InMemory…` / `Fixed…` / `Static…` implementation in a sibling `…TestSupport` library target (e.g., `StorageTestSupport` ships alongside `Storage`). TestSupport targets are importable by test targets and by previews, but are not linked into the release app. Reused across tests and SwiftUI previews:

```swift
// Sources/StorageTestSupport/InMemoryRecordStore.swift
public final class InMemoryRecordStore: RecordStore { … }
```

Previews import `*TestSupport` and inject fakes, which reinforces the "features only see protocols" rule.

---

## 7. Non-Functional Requirements

### Accessibility
- **Dynamic Type:** body / caption text uses `.font(.custom("Cormorant...", relativeTo: .body))`. Headline-style card title caps at `XXL` to protect layout; above that we switch to stacked layout.
- **VoiceOver:** each card has a single composite `accessibilityLabel` (e.g., "Jane. Met at the coffee shop. September 12, 2024, sunset. Full moon. Virgo."). Decorative layers (guilloche, gradient) marked `.accessibilityHidden(true)`.
- **Reduce Motion / Reduce Transparency / Increase Contrast:** mapped in §5.12.
- **Bold Text / Larger Text** respected via SwiftUI native mechanisms.

### Haptics
SwiftUI primitives only; no CoreHaptics custom patterns in v1.
- `.sensoryFeedback(.success, trigger: savedRecord)` on successful save
- `.sensoryFeedback(.impact(.light), trigger: cardTapped)` on list-item tap
- `.sensoryFeedback(.warning, trigger: deleteConfirmed)` before destructive confirm

### Performance targets
See §5.12. Summary:
- 60fps list scroll
- <400ms cold launch, <150ms warm
- <100ms live preview update
- <150MB resident memory at 500 records

### Internationalization
- v1 ships English only
- All strings via `String(localized:)` from day one — adding languages is mechanical
- RTL layout safe: no hard-coded leading/trailing offsets

### Privacy / security
- Zero network access in v1
- No analytics, no remote crash reporting
- Location data stored locally; never transmitted
- Photos in app sandbox; no writes to photo library
- Info.plist usage strings required: `NSLocationWhenInUseUsageDescription`, `NSMotionUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`
- Privacy policy to state on-device-only storage explicitly

---

## 8. Out of Scope (Deferred)

All deferred to v1.1+. The design keeps clean seams so landing them is additive, not a refactor.

- **Recommended section** (Phase 3): location-proximity cards on List. Visuals module already supports the 7-line density variant — a Phase-3 switch-flip.
- **Default + Advanced Sorting** (Phase 3): new protocol methods on `RecordStore`; additive.
- **2-person add flow** (Phase 4): Feature-layer extension; `RecordStore.create` takes one draft — bulk creation becomes a new method or a loop.
- **iCloud sync** (Phase 4): SwiftData → CloudKit. `ModelConfiguration` is designed around `cloudKitDatabase` optionality from day one; ship local-only, flip later.
- **Advanced Card Stack** list layout (Phase 4): new view in a Feature module; reuses `CardView`.
- **Phone / email fields**: not in proposal. Revisit post-launch based on user feedback.

---

## 9. Open Items (Flagged for Implementation)

- **Gradient color stops** — extract from Figma (blocked on MCP quota / seat upgrade); alternate path is to sample PNGs in `design-assets/Gradients/` and refine visually against the Figma.
- **Font licensing** — Cormorant SC and Cormorant Infant (Google Fonts, SIL OFL) and IBM Plex Mono (SIL OFL). License text in `DesignSystem/Resources/Fonts/LICENSES/`.
- **Shape distribution check** — after first-letter distribution is observable in real use, confirm `hash(id) % 3` gives balanced coverage across Circle / Square / Polygon. Swap the hash input if skewed. Non-urgent.
- **Reduce Motion on Create screen** — confirm that live preview updates on text change remain, while all gyroscope-driven motion is static. Likely the correct behavior.
- **Bundle ID** — confirm `com.stacksdubeurre.casualcontacts` before TestFlight.
- **Large detail presentation** — decide between fullscreen push from Medium vs fullscreen sheet. Feel out during implementation.
