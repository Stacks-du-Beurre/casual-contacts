# Plan 1 — Foundations & Data Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the Xcode project and local Swift Package with a compiler-enforced module graph. Implement every `CoreModels` type and protocol, plus the three production services (`Storage`, `Services`) and their in-memory/mock TestSupport counterparts. No UI in this plan — success is `swift test` green across all package targets.

**Architecture:** Thin iOS app target referencing a local Swift Package rooted at `Packages/`. The package exposes one library per module (`CoreModels`, `Storage`, `StorageTestSupport`, `Services`, `ServicesTestSupport`, plus UI modules filled in later plans). Features never see SwiftData, CoreLocation, or CoreMotion directly — they depend on `CoreModels` protocols. Concrete implementations are wired up in `AppFeature` (Plan 3).

**Tech Stack:** Swift 6, iOS 18+, SwiftUI, SwiftData, CoreLocation, CoreMotion, Swift Testing (`import Testing`).

**Repo:** `/Users/adam/Projects/cc` (already a git repo; `main` branch).

---

## File Structure

```
/Users/adam/Projects/cc/
├── CasualContacts/                        # Xcode wrapper folder (created manually in Task 1)
│   ├── CasualContacts.xcodeproj/          # the Xcode project
│   └── CasualContacts/                    # app target sources (minimal in this plan)
│       ├── CasualContactsApp.swift        # stub @main, replaced in Plan 3
│       ├── Info.plist                     # auto-managed by Xcode in 2026 — may be implicit
│       └── Assets.xcassets/               # app icon placeholder
├── Packages/                              # sibling to the Xcode wrapper
│   ├── Package.swift                 # declares every module + test target
│   └── Sources/
│       ├── CoreModels/
│       │   ├── Enums/
│       │   │   ├── TimeOfDay.swift
│       │   │   ├── MoonPhase.swift
│       │   │   ├── ZodiacSign.swift
│       │   │   └── GuillocheShape.swift
│       │   ├── Types/
│       │   │   ├── LocationInfo.swift
│       │   │   ├── PhotoID.swift
│       │   │   ├── DeviceAttitude.swift
│       │   │   ├── LocationAuthorization.swift
│       │   │   ├── Record.swift
│       │   │   ├── RecordDraft.swift
│       │   │   ├── RecordMetadata.swift
│       │   │   ├── ColorPalette.swift     # stub — real palettes in Plan 2
│       │   │   └── VisualAccoutrements.swift
│       │   └── Protocols/
│       │       ├── RecordStore.swift
│       │       ├── PhotoStore.swift
│       │       ├── LocationService.swift
│       │       ├── MotionService.swift
│       │       └── MetadataGenerator.swift
│       ├── Storage/
│       │   ├── PersistedRecord.swift
│       │   ├── SwiftDataRecordStore.swift
│       │   └── FileSystemPhotoStore.swift
│       ├── StorageTestSupport/
│       │   ├── InMemoryRecordStore.swift
│       │   └── InMemoryPhotoStore.swift
│       ├── Services/
│       │   ├── MoonPhaseCalculator.swift
│       │   ├── TimeOfDayCalculator.swift
│       │   ├── SystemMetadataGenerator.swift
│       │   ├── CoreLocationService.swift
│       │   └── CoreMotionService.swift
│       └── ServicesTestSupport/
│           ├── FixedMetadataGenerator.swift
│           ├── MockLocationService.swift
│           └── StaticMotionService.swift
└── Packages/Tests/
    ├── CoreModelsTests/
    ├── StorageTests/
    ├── StorageTestSupportTests/
    ├── ServicesTests/
    └── ServicesTestSupportTests/
```

**Module dependency graph (what Package.swift will encode):**

```
CoreModels           (no deps)
  ├── Storage                 (+ SwiftData)
  │   └── StorageTestSupport  (CoreModels only, not Storage)
  ├── Services                (+ CoreLocation, CoreMotion)
  │   └── ServicesTestSupport (CoreModels only, not Services)
```

Note: `*TestSupport` modules depend on `CoreModels` only — they implement the same protocols as production code without importing the production module. This enforces the "preview/test code doesn't drag SwiftData into the binary" rule.

---

## Task 1: Create Xcode project + Package scaffold

**Files:**
- Create (manually in Xcode): `CasualContacts.xcodeproj/`, `CasualContacts/CasualContactsApp.swift`, `CasualContacts/Info.plist`, `CasualContacts/Assets.xcassets/`
- Create: `Packages/Package.swift`
- Create: `.gitignore` (append SwiftPM/Xcode entries)

- [ ] **Step 1: Manual — user creates Xcode project**

Ask the user (not the agent — this is a manual step) to:
1. Open Xcode.
2. File → New → Project → iOS → App.
3. Product Name: `CasualContacts`. Team: none (for now). Organization Identifier: `com.stacksdubeurre`. Interface: SwiftUI. Language: Swift. Storage: None. Include Tests: NO (we use Swift Package tests).
4. Save location: `/Users/adam/Projects/cc/` (uncheck "Create Git repository" — repo already exists).
5. After creation, in Project settings → Info tab → set iOS Deployment Target to 18.0.
6. Close Xcode.

After user confirms completion, verify:

Run: `ls /Users/adam/Projects/cc/CasualContacts.xcodeproj && ls /Users/adam/Projects/cc/CasualContacts/`
Expected: both directories exist, `CasualContacts/` contains `CasualContactsApp.swift`, `ContentView.swift`, `Assets.xcassets`.

- [ ] **Step 2: Delete Xcode-generated ContentView**

We don't need ContentView — `CasualContactsApp.swift` will be rewritten in Plan 3 to import `AppFeature`. For Plan 1 we leave the default app untouched.

Run:
```bash
rm /Users/adam/Projects/cc/CasualContacts/ContentView.swift
```

Then open `CasualContactsApp.swift` and replace its body with a stub:

`CasualContacts/CasualContactsApp.swift`:
```swift
import SwiftUI

@main
struct CasualContactsApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Hello, Casual Contacts")
        }
    }
}
```

- [ ] **Step 3: Create Packages directory + empty Package.swift**

Run:
```bash
mkdir -p /Users/adam/Projects/cc/Packages/Sources /Users/adam/Projects/cc/Packages/Tests
```

Create `Packages/Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CasualContactsPackages",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [],
    targets: []
)
```

- [ ] **Step 4: Update `.gitignore`**

Check if a `.gitignore` exists:
```bash
cat /Users/adam/Projects/cc/.gitignore 2>/dev/null || echo "NO GITIGNORE"
```

Create or append the following (replace file entirely if `NO GITIGNORE`):

`.gitignore`:
```
# macOS
.DS_Store

# Xcode
build/
DerivedData/
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3
xcuserdata/
*.xccheckout
*.moved-aside
*.xcuserstate
*.xcscmblueprint

# Swift Package Manager
Packages/.build/
Packages/.swiftpm/
Packages/Package.resolved

# Generated SVG→Swift files (rebuilt by build tool)
Packages/Sources/Visuals/Guilloche/Generated/

# Provisioning / signing
*.p8
*.p12
*.mobileprovision
```

- [ ] **Step 5: Verify package builds (empty but valid)**

Run: `cd /Users/adam/Projects/cc/Packages && swift build`
Expected: `Build complete!` with no output (no targets to build).

- [ ] **Step 6: Commit**

```bash
cd /Users/adam/Projects/cc
git add CasualContacts.xcodeproj CasualContacts/ Packages/Package.swift .gitignore
git commit -m "chore(scaffold): add Xcode project + empty Swift Package

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: CoreModels target + enum foundations

**Files:**
- Modify: `Packages/Package.swift`
- Create: `Packages/Sources/CoreModels/Enums/TimeOfDay.swift`
- Create: `Packages/Sources/CoreModels/Enums/MoonPhase.swift`
- Create: `Packages/Sources/CoreModels/Enums/ZodiacSign.swift`
- Create: `Packages/Sources/CoreModels/Enums/GuillocheShape.swift`
- Create: `Packages/Tests/CoreModelsTests/EnumsTests.swift`

- [ ] **Step 1: Add CoreModels + CoreModelsTests to Package.swift**

Replace `Packages/Package.swift` with:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CasualContactsPackages",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "CoreModels", targets: ["CoreModels"])
    ],
    targets: [
        .target(
            name: "CoreModels",
            path: "Sources/CoreModels"
        ),
        .testTarget(
            name: "CoreModelsTests",
            dependencies: ["CoreModels"],
            path: "Tests/CoreModelsTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 2: Write failing enum tests**

Create `Packages/Tests/CoreModelsTests/EnumsTests.swift`:
```swift
import Testing
import CoreModels

@Suite struct EnumsTests {

    @Test func timeOfDayHasSevenCases() {
        #expect(TimeOfDay.allCases.count == 7)
        #expect(TimeOfDay.allCases.contains(.dawn))
        #expect(TimeOfDay.allCases.contains(.midnight))
    }

    @Test func moonPhaseHasEightCases() {
        #expect(MoonPhase.allCases.count == 8)
        #expect(MoonPhase.allCases.contains(.newMoon))
        #expect(MoonPhase.allCases.contains(.waningCrescent))
    }

    @Test func zodiacHasTwelveCases() {
        #expect(ZodiacSign.allCases.count == 12)
        #expect(ZodiacSign.allCases.contains(.aries))
        #expect(ZodiacSign.allCases.contains(.pisces))
    }

    @Test func guillocheShapeHasThreeCases() {
        #expect(GuillocheShape.allCases.count == 3)
    }

    @Test func timeOfDayRawValuesStable() throws {
        let encoded = try JSONEncoder().encode(TimeOfDay.sunset)
        #expect(String(data: encoded, encoding: .utf8) == "\"sunset\"")
    }

    @Test func moonPhaseRoundTripsThroughJSON() throws {
        let original = MoonPhase.waxingGibbous
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MoonPhase.self, from: data)
        #expect(decoded == original)
    }
}
```

- [ ] **Step 3: Verify tests fail (compilation error)**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter CoreModelsTests`
Expected: FAIL with "no such module 'CoreModels'" or similar (the directory doesn't exist yet, so package resolution fails).

- [ ] **Step 4: Create enum source files**

`Packages/Sources/CoreModels/Enums/TimeOfDay.swift`:
```swift
import Foundation

public enum TimeOfDay: String, CaseIterable, Codable, Sendable {
    case dawn, sunrise, midday, sunset, dusk, night, midnight
}
```

`Packages/Sources/CoreModels/Enums/MoonPhase.swift`:
```swift
import Foundation

public enum MoonPhase: String, CaseIterable, Codable, Sendable {
    case newMoon, waxingCrescent, firstQuarter, waxingGibbous
    case fullMoon, waningGibbous, thirdQuarter, waningCrescent
}
```

`Packages/Sources/CoreModels/Enums/ZodiacSign.swift`:
```swift
import Foundation

public enum ZodiacSign: String, CaseIterable, Codable, Sendable {
    case aries, taurus, gemini, cancer, leo, virgo
    case libra, scorpio, sagittarius, capricorn, aquarius, pisces
}
```

`Packages/Sources/CoreModels/Enums/GuillocheShape.swift`:
```swift
import Foundation

public enum GuillocheShape: String, CaseIterable, Codable, Sendable {
    case circle, square, polygon
}
```

- [ ] **Step 5: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter CoreModelsTests`
Expected: 6 tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/
git commit -m "feat(core-models): add TimeOfDay, MoonPhase, ZodiacSign, GuillocheShape enums

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: CoreModels — Plain value types

**Files:**
- Create: `Packages/Sources/CoreModels/Types/LocationInfo.swift`
- Create: `Packages/Sources/CoreModels/Types/PhotoID.swift`
- Create: `Packages/Sources/CoreModels/Types/DeviceAttitude.swift`
- Create: `Packages/Sources/CoreModels/Types/LocationAuthorization.swift`
- Create: `Packages/Tests/CoreModelsTests/ValueTypesTests.swift`

- [ ] **Step 1: Write failing tests**

`Packages/Tests/CoreModelsTests/ValueTypesTests.swift`:
```swift
import Testing
import Foundation
@testable import CoreModels

@Suite struct ValueTypesTests {

    @Test func locationInfoRoundTripsThroughJSON() throws {
        let original = LocationInfo(latitude: 37.7749, longitude: -122.4194, label: "San Francisco")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LocationInfo.self, from: data)
        #expect(decoded == original)
    }

    @Test func photoIDEqualityUsesFilename() {
        let a = PhotoID(filename: "abc.heic")
        let b = PhotoID(filename: "abc.heic")
        let c = PhotoID(filename: "def.heic")
        #expect(a == b)
        #expect(a != c)
    }

    @Test func deviceAttitudeZeroIsAllZeros() {
        #expect(DeviceAttitude.zero.pitch == 0)
        #expect(DeviceAttitude.zero.roll == 0)
    }

    @Test func deviceAttitudeClamps() {
        let clamped = DeviceAttitude(pitch: 5.0, roll: -9.0).clamped()
        #expect(clamped.pitch == 1.0)
        #expect(clamped.roll == -1.0)
    }

    @Test func locationAuthorizationHasThreeCases() {
        let all: [LocationAuthorization] = [.authorized, .denied, .notDetermined]
        #expect(all.count == 3)
    }
}
```

- [ ] **Step 2: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter ValueTypesTests`
Expected: FAIL with "no such type `LocationInfo`" etc.

- [ ] **Step 3: Create type source files**

`Packages/Sources/CoreModels/Types/LocationInfo.swift`:
```swift
import Foundation

public struct LocationInfo: Hashable, Codable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let label: String?

    public init(latitude: Double, longitude: Double, label: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.label = label
    }
}
```

`Packages/Sources/CoreModels/Types/PhotoID.swift`:
```swift
import Foundation

public struct PhotoID: Hashable, Codable, Sendable {
    public let filename: String

    public init(filename: String) {
        self.filename = filename
    }
}
```

`Packages/Sources/CoreModels/Types/DeviceAttitude.swift`:
```swift
import Foundation

public struct DeviceAttitude: Hashable, Sendable {
    public let pitch: Double
    public let roll: Double

    public init(pitch: Double, roll: Double) {
        self.pitch = pitch
        self.roll = roll
    }

    public static let zero = DeviceAttitude(pitch: 0, roll: 0)

    public func clamped(to range: ClosedRange<Double> = -1.0...1.0) -> DeviceAttitude {
        DeviceAttitude(
            pitch: min(max(pitch, range.lowerBound), range.upperBound),
            roll: min(max(roll, range.lowerBound), range.upperBound)
        )
    }
}
```

`Packages/Sources/CoreModels/Types/LocationAuthorization.swift`:
```swift
import Foundation

public enum LocationAuthorization: Sendable, Equatable {
    case authorized
    case denied
    case notDetermined
}
```

- [ ] **Step 4: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter ValueTypesTests`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/CoreModels/Types Packages/Tests/CoreModelsTests/ValueTypesTests.swift
git commit -m "feat(core-models): add LocationInfo, PhotoID, DeviceAttitude, LocationAuthorization

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: CoreModels — Record, RecordMetadata, RecordDraft

**Files:**
- Create: `Packages/Sources/CoreModels/Types/RecordMetadata.swift`
- Create: `Packages/Sources/CoreModels/Types/Record.swift`
- Create: `Packages/Sources/CoreModels/Types/RecordDraft.swift`
- Create: `Packages/Tests/CoreModelsTests/RecordTests.swift`

- [ ] **Step 1: Write failing tests**

`Packages/Tests/CoreModelsTests/RecordTests.swift`:
```swift
import Testing
import Foundation
@testable import CoreModels

@Suite struct RecordTests {

    private let sampleID = UUID()
    private let sampleDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func recordIsIdentifiableByID() {
        let record = Self.makeRecord(id: sampleID)
        #expect(record.id == sampleID)
    }

    @Test func recordRoundTripsThroughJSON() throws {
        let original = Self.makeRecord(id: sampleID, zodiac: .virgo)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Record.self, from: data)
        #expect(decoded == original)
    }

    @Test func recordWithNilZodiacRoundTrips() throws {
        let original = Self.makeRecord(id: sampleID, zodiac: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Record.self, from: data)
        #expect(decoded.zodiacSign == nil)
    }

    @Test func recordDraftInitializesWithDefaults() {
        let draft = RecordDraft(name: "Jane")
        #expect(draft.name == "Jane")
        #expect(draft.description == "")
        #expect(draft.photo == nil)
        #expect(draft.location == nil)
        #expect(draft.zodiacSign == nil)
    }

    @Test func recordMetadataEqualityUsesAllFields() {
        let m1 = RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
        let m2 = RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
        let m3 = RecordMetadata(timeOfDay: .sunset, moonPhase: .newMoon)
        #expect(m1 == m2)
        #expect(m1 != m3)
    }

    // MARK: - Helpers

    private static func makeRecord(id: UUID, zodiac: ZodiacSign? = nil) -> Record {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return Record(
            id: id,
            name: "Jane",
            description: "Met at the coffee shop",
            photoID: nil,
            location: LocationInfo(latitude: 37.77, longitude: -122.41, label: "SF"),
            zodiacSign: zodiac,
            createdAt: date,
            updatedAt: date,
            metadata: RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
        )
    }
}
```

- [ ] **Step 2: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter RecordTests`
Expected: FAIL — `Record`, `RecordMetadata`, `RecordDraft` not found.

- [ ] **Step 3: Create source files**

`Packages/Sources/CoreModels/Types/RecordMetadata.swift`:
```swift
import Foundation

public struct RecordMetadata: Hashable, Codable, Sendable {
    public let timeOfDay: TimeOfDay
    public let moonPhase: MoonPhase

    public init(timeOfDay: TimeOfDay, moonPhase: MoonPhase) {
        self.timeOfDay = timeOfDay
        self.moonPhase = moonPhase
    }
}
```

`Packages/Sources/CoreModels/Types/Record.swift`:
```swift
import Foundation

public struct Record: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var photoID: PhotoID?
    public var location: LocationInfo?
    public var zodiacSign: ZodiacSign?
    public let createdAt: Date
    public var updatedAt: Date
    public let metadata: RecordMetadata

    public init(
        id: UUID,
        name: String,
        description: String,
        photoID: PhotoID?,
        location: LocationInfo?,
        zodiacSign: ZodiacSign?,
        createdAt: Date,
        updatedAt: Date,
        metadata: RecordMetadata
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.photoID = photoID
        self.location = location
        self.zodiacSign = zodiacSign
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
}
```

`Packages/Sources/CoreModels/Types/RecordDraft.swift`:
```swift
import Foundation

public struct RecordDraft: Sendable {
    public var name: String
    public var description: String
    public var photo: Data?
    public var location: LocationInfo?
    public var zodiacSign: ZodiacSign?

    public init(
        name: String,
        description: String = "",
        photo: Data? = nil,
        location: LocationInfo? = nil,
        zodiacSign: ZodiacSign? = nil
    ) {
        self.name = name
        self.description = description
        self.photo = photo
        self.location = location
        self.zodiacSign = zodiacSign
    }
}
```

- [ ] **Step 4: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter RecordTests`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/CoreModels/Types Packages/Tests/CoreModelsTests/RecordTests.swift
git commit -m "feat(core-models): add Record, RecordMetadata, RecordDraft

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: CoreModels — VisualAccoutrements derivation

**Files:**
- Create: `Packages/Sources/CoreModels/Types/ColorPalette.swift`
- Create: `Packages/Sources/CoreModels/Types/VisualAccoutrements.swift`
- Create: `Packages/Tests/CoreModelsTests/VisualAccoutrementsTests.swift`

- [ ] **Step 1: Write failing tests**

`Packages/Tests/CoreModelsTests/VisualAccoutrementsTests.swift`:
```swift
import Testing
import Foundation
@testable import CoreModels

@Suite struct VisualAccoutrementsTests {

    @Test func derivationIsDeterministicAcrossCalls() {
        let record = Self.makeRecord(id: UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!, name: "Jane")
        let a = record.accoutrements
        let b = record.accoutrements
        #expect(a == b)
    }

    @Test func letterIsFirstCharacterUppercased() {
        let record = Self.makeRecord(id: UUID(), name: "jane")
        #expect(record.accoutrements.letter == "J")
    }

    @Test func letterFallsBackToAForEmptyName() {
        let record = Self.makeRecord(id: UUID(), name: "")
        #expect(record.accoutrements.letter == "A")
    }

    @Test func paletteIsDerivedFromTimeOfDay() {
        let record = Self.makeRecord(id: UUID(), name: "Jane", timeOfDay: .sunset)
        #expect(record.accoutrements.palette.timeOfDay == .sunset)
    }

    @Test func guillocheShapeIsStableForSameID() {
        let id = UUID()
        let a = Self.makeRecord(id: id, name: "A").accoutrements.guillocheShape
        let b = Self.makeRecord(id: id, name: "B").accoutrements.guillocheShape
        // Different names, same id → same shape
        #expect(a == b)
    }

    // MARK: - Helpers

    private static func makeRecord(id: UUID, name: String, timeOfDay: TimeOfDay = .midday) -> Record {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return Record(
            id: id,
            name: name,
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: date,
            updatedAt: date,
            metadata: RecordMetadata(timeOfDay: timeOfDay, moonPhase: .fullMoon)
        )
    }
}
```

- [ ] **Step 2: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter VisualAccoutrementsTests`
Expected: FAIL — `ColorPalette`, `VisualAccoutrements`, `Record.accoutrements` not found.

- [ ] **Step 3: Create ColorPalette stub**

This is a stub type — Plan 2 fills in real gradient stops. For now it just tags a palette by TimeOfDay so tests can verify derivation.

`Packages/Sources/CoreModels/Types/ColorPalette.swift`:
```swift
import Foundation

/// Placeholder identity for a time-of-day palette.
/// The actual gradient definitions are supplied by the `DesignSystem` module in Plan 2.
public struct ColorPalette: Hashable, Sendable {
    public let timeOfDay: TimeOfDay

    public init(timeOfDay: TimeOfDay) {
        self.timeOfDay = timeOfDay
    }
}
```

- [ ] **Step 4: Create VisualAccoutrements + Record extension**

`Packages/Sources/CoreModels/Types/VisualAccoutrements.swift`:
```swift
import Foundation

public struct VisualAccoutrements: Hashable, Sendable {
    public let palette: ColorPalette
    public let letter: Character
    public let guillocheShape: GuillocheShape

    public init(palette: ColorPalette, letter: Character, guillocheShape: GuillocheShape) {
        self.palette = palette
        self.letter = letter
        self.guillocheShape = guillocheShape
    }
}

public extension Record {
    var accoutrements: VisualAccoutrements {
        let firstLetter: Character = {
            guard let c = name.first, c.isLetter else { return "A" }
            return Character(String(c).uppercased())
        }()

        let shapeIndex = abs(id.uuidString.hashValue) % GuillocheShape.allCases.count
        let shape = GuillocheShape.allCases[shapeIndex]

        return VisualAccoutrements(
            palette: ColorPalette(timeOfDay: metadata.timeOfDay),
            letter: firstLetter,
            guillocheShape: shape
        )
    }
}
```

Note on `id.uuidString.hashValue`: we hash the UUID's string form so the result is stable across SwiftData fetches (raw `UUID.hashValue` is also stable per process but stringifying makes intent explicit and the stored result stable across reads).

- [ ] **Step 5: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter VisualAccoutrementsTests`
Expected: 5 tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/CoreModels/Types/ColorPalette.swift Packages/Sources/CoreModels/Types/VisualAccoutrements.swift Packages/Tests/CoreModelsTests/VisualAccoutrementsTests.swift
git commit -m "feat(core-models): derive VisualAccoutrements from stable record fields

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: CoreModels — Service protocols

**Files:**
- Create: `Packages/Sources/CoreModels/Protocols/RecordStore.swift`
- Create: `Packages/Sources/CoreModels/Protocols/PhotoStore.swift`
- Create: `Packages/Sources/CoreModels/Protocols/LocationService.swift`
- Create: `Packages/Sources/CoreModels/Protocols/MotionService.swift`
- Create: `Packages/Sources/CoreModels/Protocols/MetadataGenerator.swift`

No tests this task — protocols have no runtime behavior on their own. Conformers are tested in their own tasks.

- [ ] **Step 1: Create RecordStore protocol**

`Packages/Sources/CoreModels/Protocols/RecordStore.swift`:
```swift
import Foundation

public protocol RecordStore: AnyObject, Sendable {
    @MainActor var records: [Record] { get }
    func create(_ draft: RecordDraft, metadata: RecordMetadata) async throws -> Record
    func update(_ record: Record) async throws
    func delete(id: Record.ID) async throws
    @MainActor func search(_ query: String) -> [Record]
}

public enum RecordStoreError: Error, Sendable, Equatable {
    case notFound(Record.ID)
    case saveFailed(reason: String)
}
```

The caller (`FeatureCreate` in Plan 3) computes `metadata` by invoking a `MetadataGenerator` with the current date + location, then hands both to the store. Keeps the store focused on persistence.

- [ ] **Step 2: Create PhotoStore protocol**

`Packages/Sources/CoreModels/Protocols/PhotoStore.swift`:
```swift
import Foundation

public protocol PhotoStore: Sendable {
    func save(_ data: Data) async throws -> PhotoID
    func load(_ id: PhotoID) async throws -> Data?
    func delete(_ id: PhotoID) async throws
}

public enum PhotoStoreError: Error, Sendable, Equatable {
    case writeFailed(reason: String)
    case notFound(PhotoID)
}
```

- [ ] **Step 3: Create LocationService protocol**

`Packages/Sources/CoreModels/Protocols/LocationService.swift`:
```swift
import Foundation

public protocol LocationService: AnyObject, Sendable {
    func requestAuthorization() async -> LocationAuthorization
    func currentLocation() async throws -> LocationInfo?
}

public enum LocationServiceError: Error, Sendable, Equatable {
    case notAuthorized
    case unavailable
}
```

- [ ] **Step 4: Create MotionService protocol**

`Packages/Sources/CoreModels/Protocols/MotionService.swift`:
```swift
import Foundation

public protocol MotionService: AnyObject, Sendable {
    var attitude: AsyncStream<DeviceAttitude> { get }
    func start()
    func stop()
}
```

- [ ] **Step 5: Create MetadataGenerator protocol**

`Packages/Sources/CoreModels/Protocols/MetadataGenerator.swift`:
```swift
import Foundation

public protocol MetadataGenerator: Sendable {
    func metadata(at date: Date, location: LocationInfo?) -> RecordMetadata
}
```

- [ ] **Step 6: Verify package builds**

Run: `cd /Users/adam/Projects/cc/Packages && swift build`
Expected: `Build complete!`

- [ ] **Step 7: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/CoreModels/Protocols
git commit -m "feat(core-models): add service protocols (RecordStore, PhotoStore, LocationService, MotionService, MetadataGenerator)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Storage module + PersistedRecord

**Files:**
- Modify: `Packages/Package.swift`
- Create: `Packages/Sources/Storage/PersistedRecord.swift`
- Create: `Packages/Tests/StorageTests/PersistedRecordTests.swift`

- [ ] **Step 1: Add Storage + StorageTests to Package.swift**

Replace `Packages/Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CasualContactsPackages",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "CoreModels", targets: ["CoreModels"]),
        .library(name: "Storage", targets: ["Storage"])
    ],
    targets: [
        .target(
            name: "CoreModels",
            path: "Sources/CoreModels"
        ),
        .testTarget(
            name: "CoreModelsTests",
            dependencies: ["CoreModels"],
            path: "Tests/CoreModelsTests"
        ),
        .target(
            name: "Storage",
            dependencies: ["CoreModels"],
            path: "Sources/Storage"
        ),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Storage", "CoreModels"],
            path: "Tests/StorageTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 2: Write failing test**

`Packages/Tests/StorageTests/PersistedRecordTests.swift`:
```swift
import Testing
import Foundation
import SwiftData
@testable import Storage

@Suite struct PersistedRecordTests {

    @Test func canInsertAndFetchPersistedRecord() throws {
        let container = try ModelContainer(
            for: PersistedRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let record = PersistedRecord(
            id: UUID(),
            name: "Jane",
            recordDescription: "Met at the coffee shop",
            photoFilename: nil,
            latitude: nil,
            longitude: nil,
            locationLabel: nil,
            zodiacSignRaw: nil,
            createdAt: Date(),
            updatedAt: Date(),
            timeOfDayRaw: "sunset",
            moonPhaseRaw: "fullMoon"
        )
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PersistedRecord>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Jane")
    }
}
```

- [ ] **Step 3: Verify test fails**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter PersistedRecordTests`
Expected: FAIL — `PersistedRecord` not found.

- [ ] **Step 4: Create PersistedRecord**

`Packages/Sources/Storage/PersistedRecord.swift`:
```swift
import Foundation
import SwiftData

@Model
public final class PersistedRecord {
    public var id: UUID
    public var name: String
    public var recordDescription: String
    public var photoFilename: String?
    public var latitude: Double?
    public var longitude: Double?
    public var locationLabel: String?
    public var zodiacSignRaw: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var timeOfDayRaw: String
    public var moonPhaseRaw: String

    public init(
        id: UUID,
        name: String,
        recordDescription: String,
        photoFilename: String?,
        latitude: Double?,
        longitude: Double?,
        locationLabel: String?,
        zodiacSignRaw: String?,
        createdAt: Date,
        updatedAt: Date,
        timeOfDayRaw: String,
        moonPhaseRaw: String
    ) {
        self.id = id
        self.name = name
        self.recordDescription = recordDescription
        self.photoFilename = photoFilename
        self.latitude = latitude
        self.longitude = longitude
        self.locationLabel = locationLabel
        self.zodiacSignRaw = zodiacSignRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.timeOfDayRaw = timeOfDayRaw
        self.moonPhaseRaw = moonPhaseRaw
    }
}
```

- [ ] **Step 5: Verify test passes**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter PersistedRecordTests`
Expected: 1 test passes.

- [ ] **Step 6: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Package.swift Packages/Sources/Storage Packages/Tests/StorageTests/PersistedRecordTests.swift
git commit -m "feat(storage): add Storage module with @Model PersistedRecord

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Storage — SwiftDataRecordStore (create, fetch, mapping)

**Files:**
- Create: `Packages/Sources/Storage/SwiftDataRecordStore.swift`
- Create: `Packages/Tests/StorageTests/SwiftDataRecordStoreTests.swift`

- [ ] **Step 1: Write failing tests**

`Packages/Tests/StorageTests/SwiftDataRecordStoreTests.swift`:
```swift
import Testing
import Foundation
import SwiftData
import CoreModels
@testable import Storage

@MainActor
@Suite struct SwiftDataRecordStoreTests {

    private func makeStore() throws -> SwiftDataRecordStore {
        let container = try ModelContainer(
            for: PersistedRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SwiftDataRecordStore(container: container)
    }

    private let sampleMetadata = RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)

    @Test func createReturnsRecordWithGeneratedIDAndTimestamps() async throws {
        let store = try makeStore()
        let draft = RecordDraft(name: "Jane", description: "Met at the coffee shop")

        let record = try await store.create(draft, metadata: sampleMetadata)

        #expect(record.name == "Jane")
        #expect(record.description == "Met at the coffee shop")
        #expect(record.createdAt == record.updatedAt)
        #expect(record.metadata == sampleMetadata)
    }

    @Test func createdRecordAppearsInRecords() async throws {
        let store = try makeStore()
        _ = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)

        #expect(store.records.count == 1)
        #expect(store.records.first?.name == "Jane")
    }

    @Test func roundTripPreservesAllFields() async throws {
        let store = try makeStore()
        let draft = RecordDraft(
            name: "Jane",
            description: "Met at the coffee shop",
            location: LocationInfo(latitude: 37.77, longitude: -122.41, label: "SF"),
            zodiacSign: .virgo
        )

        let created = try await store.create(draft, metadata: sampleMetadata)

        let fetched = store.records.first { $0.id == created.id }
        #expect(fetched == created)
    }

    @Test func updateModifiesExistingRecord() async throws {
        let store = try makeStore()
        var record = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)

        record.name = "Janet"
        record.zodiacSign = .virgo
        try await store.update(record)

        let fetched = store.records.first { $0.id == record.id }
        #expect(fetched?.name == "Janet")
        #expect(fetched?.zodiacSign == .virgo)
    }

    @Test func deleteRemovesRecord() async throws {
        let store = try makeStore()
        let record = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)

        try await store.delete(id: record.id)

        #expect(store.records.isEmpty)
    }

    @Test func updateThrowsForMissingRecord() async throws {
        let store = try makeStore()
        let missing = Record(
            id: UUID(),
            name: "Ghost",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)
        )

        await #expect(throws: RecordStoreError.notFound(missing.id)) {
            try await store.update(missing)
        }
    }
}
```

- [ ] **Step 2: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter SwiftDataRecordStoreTests`
Expected: FAIL — `SwiftDataRecordStore` not found.

- [ ] **Step 3: Create SwiftDataRecordStore**

`Packages/Sources/Storage/SwiftDataRecordStore.swift`:
```swift
import Foundation
import SwiftData
import CoreModels
import Observation

@MainActor
@Observable
public final class SwiftDataRecordStore: RecordStore {

    private let container: ModelContainer
    private let context: ModelContext
    public private(set) var records: [Record] = []

    public init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
        reload()
    }

    // MARK: - RecordStore

    public func create(_ draft: RecordDraft, metadata: RecordMetadata) async throws -> Record {
        let now = Date()
        let persisted = PersistedRecord(
            id: UUID(),
            name: draft.name,
            recordDescription: draft.description,
            photoFilename: nil,  // PhotoStore integration is owned by FeatureCreate in Plan 3
            latitude: draft.location?.latitude,
            longitude: draft.location?.longitude,
            locationLabel: draft.location?.label,
            zodiacSignRaw: draft.zodiacSign?.rawValue,
            createdAt: now,
            updatedAt: now,
            timeOfDayRaw: metadata.timeOfDay.rawValue,
            moonPhaseRaw: metadata.moonPhase.rawValue
        )
        context.insert(persisted)
        do {
            try context.save()
        } catch {
            throw RecordStoreError.saveFailed(reason: String(describing: error))
        }
        reload()
        guard let created = records.first(where: { $0.id == persisted.id }) else {
            throw RecordStoreError.saveFailed(reason: "record missing after insert")
        }
        return created
    }

    public func update(_ record: Record) async throws {
        let id = record.id
        var descriptor = FetchDescriptor<PersistedRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1

        guard let persisted = try context.fetch(descriptor).first else {
            throw RecordStoreError.notFound(id)
        }
        persisted.name = record.name
        persisted.recordDescription = record.description
        persisted.photoFilename = record.photoID?.filename
        persisted.latitude = record.location?.latitude
        persisted.longitude = record.location?.longitude
        persisted.locationLabel = record.location?.label
        persisted.zodiacSignRaw = record.zodiacSign?.rawValue
        persisted.updatedAt = Date()
        do {
            try context.save()
        } catch {
            throw RecordStoreError.saveFailed(reason: String(describing: error))
        }
        reload()
    }

    public func delete(id: Record.ID) async throws {
        var descriptor = FetchDescriptor<PersistedRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let persisted = try context.fetch(descriptor).first else {
            throw RecordStoreError.notFound(id)
        }
        context.delete(persisted)
        try context.save()
        reload()
    }

    public func search(_ query: String) -> [Record] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return records }
        let lowered = trimmed.lowercased()
        return records.filter { $0.name.lowercased().contains(lowered) }
    }

    // MARK: - Private

    private func reload() {
        let descriptor = FetchDescriptor<PersistedRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let persistedList = (try? context.fetch(descriptor)) ?? []
        records = persistedList.map(Record.init(persisted:))
    }
}

// MARK: - Mapping

extension Record {
    init(persisted: PersistedRecord) {
        let location: LocationInfo? = {
            guard let lat = persisted.latitude, let lon = persisted.longitude else { return nil }
            return LocationInfo(latitude: lat, longitude: lon, label: persisted.locationLabel)
        }()
        self.init(
            id: persisted.id,
            name: persisted.name,
            description: persisted.recordDescription,
            photoID: persisted.photoFilename.map(PhotoID.init(filename:)),
            location: location,
            zodiacSign: persisted.zodiacSignRaw.flatMap(ZodiacSign.init(rawValue:)),
            createdAt: persisted.createdAt,
            updatedAt: persisted.updatedAt,
            metadata: RecordMetadata(
                timeOfDay: TimeOfDay(rawValue: persisted.timeOfDayRaw) ?? .midday,
                moonPhase: MoonPhase(rawValue: persisted.moonPhaseRaw) ?? .fullMoon
            )
        )
    }
}
```

- [ ] **Step 4: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter SwiftDataRecordStoreTests`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/Storage/SwiftDataRecordStore.swift Packages/Tests/StorageTests/SwiftDataRecordStoreTests.swift
git commit -m "feat(storage): implement SwiftDataRecordStore with CRUD + search

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Storage — SwiftDataRecordStore search behaviors

**Files:**
- Modify: `Packages/Tests/StorageTests/SwiftDataRecordStoreTests.swift`

No new source — `search` was implemented in Task 8. This task adds test coverage.

- [ ] **Step 1: Append search tests**

Append to `Packages/Tests/StorageTests/SwiftDataRecordStoreTests.swift` (before the closing `}` of `SwiftDataRecordStoreTests`):

```swift
    @Test func searchWithEmptyQueryReturnsAllRecords() async throws {
        let store = try makeStore()
        _ = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)
        _ = try await store.create(RecordDraft(name: "John"), metadata: sampleMetadata)

        let results = store.search("")

        #expect(results.count == 2)
    }

    @Test func searchFiltersByNameCaseInsensitive() async throws {
        let store = try makeStore()
        _ = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)
        _ = try await store.create(RecordDraft(name: "John"), metadata: sampleMetadata)
        _ = try await store.create(RecordDraft(name: "Janet"), metadata: sampleMetadata)

        let results = store.search("jan")

        #expect(results.count == 2)
        #expect(Set(results.map(\.name)) == ["Jane", "Janet"])
    }

    @Test func searchTrimsWhitespace() async throws {
        let store = try makeStore()
        _ = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)

        let results = store.search("   Jane   ")

        #expect(results.count == 1)
    }
```

- [ ] **Step 2: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter SwiftDataRecordStoreTests`
Expected: 9 tests pass (6 from Task 8 + 3 new).

- [ ] **Step 3: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Tests/StorageTests/SwiftDataRecordStoreTests.swift
git commit -m "test(storage): cover SwiftDataRecordStore search behaviors

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: StorageTestSupport — InMemoryRecordStore

**Files:**
- Modify: `Packages/Package.swift`
- Create: `Packages/Sources/StorageTestSupport/InMemoryRecordStore.swift`
- Create: `Packages/Tests/StorageTestSupportTests/InMemoryRecordStoreTests.swift`

- [ ] **Step 1: Add StorageTestSupport target to Package.swift**

Insert into `targets:` array (after the StorageTests entry):
```swift
        .target(
            name: "StorageTestSupport",
            dependencies: ["CoreModels"],
            path: "Sources/StorageTestSupport"
        ),
        .testTarget(
            name: "StorageTestSupportTests",
            dependencies: ["StorageTestSupport", "CoreModels"],
            path: "Tests/StorageTestSupportTests"
        ),
```

Also add to `products:`:
```swift
        .library(name: "StorageTestSupport", targets: ["StorageTestSupport"]),
```

- [ ] **Step 2: Write failing tests**

`Packages/Tests/StorageTestSupportTests/InMemoryRecordStoreTests.swift`:
```swift
import Testing
import Foundation
import CoreModels
@testable import StorageTestSupport

@MainActor
@Suite struct InMemoryRecordStoreTests {

    private let sampleMetadata = RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)

    @Test func createAddsRecordAndReturnsIt() async throws {
        let store = InMemoryRecordStore()
        let record = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)

        #expect(record.name == "Jane")
        #expect(store.records.count == 1)
    }

    @Test func createdRecordsAreSortedNewestFirst() async throws {
        let store = InMemoryRecordStore()
        _ = try await store.create(RecordDraft(name: "A"), metadata: sampleMetadata)
        try await Task.sleep(nanoseconds: 1_000_000)
        _ = try await store.create(RecordDraft(name: "B"), metadata: sampleMetadata)

        #expect(store.records.map(\.name) == ["B", "A"])
    }

    @Test func deleteRemovesRecord() async throws {
        let store = InMemoryRecordStore()
        let record = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)

        try await store.delete(id: record.id)

        #expect(store.records.isEmpty)
    }

    @Test func updateThrowsForMissingRecord() async throws {
        let store = InMemoryRecordStore()
        let ghost = Record(
            id: UUID(),
            name: "Ghost",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)
        )

        await #expect(throws: RecordStoreError.notFound(ghost.id)) {
            try await store.update(ghost)
        }
    }

    @Test func searchIsCaseInsensitive() async throws {
        let store = InMemoryRecordStore()
        _ = try await store.create(RecordDraft(name: "Jane"), metadata: sampleMetadata)
        _ = try await store.create(RecordDraft(name: "John"), metadata: sampleMetadata)

        #expect(store.search("ja").map(\.name) == ["Jane"])
    }

    @Test func preloadedRecordsAreAvailable() async throws {
        let seed = Record(
            id: UUID(),
            name: "Preloaded",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)
        )
        let store = InMemoryRecordStore(seed: [seed])

        #expect(store.records.count == 1)
        #expect(store.records.first?.name == "Preloaded")
    }
}
```

- [ ] **Step 3: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter InMemoryRecordStoreTests`
Expected: FAIL — `InMemoryRecordStore` not found.

- [ ] **Step 4: Create InMemoryRecordStore**

`Packages/Sources/StorageTestSupport/InMemoryRecordStore.swift`:
```swift
import Foundation
import CoreModels
import Observation

@MainActor
@Observable
public final class InMemoryRecordStore: RecordStore {

    public private(set) var records: [Record] = []

    public init(seed: [Record] = []) {
        self.records = seed.sorted { $0.createdAt > $1.createdAt }
    }

    public func create(_ draft: RecordDraft, metadata: RecordMetadata) async throws -> Record {
        let now = Date()
        let record = Record(
            id: UUID(),
            name: draft.name,
            description: draft.description,
            photoID: nil,
            location: draft.location,
            zodiacSign: draft.zodiacSign,
            createdAt: now,
            updatedAt: now,
            metadata: metadata
        )
        records.insert(record, at: 0)
        return record
    }

    public func update(_ record: Record) async throws {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else {
            throw RecordStoreError.notFound(record.id)
        }
        var updated = record
        updated.updatedAt = Date()
        records[index] = updated
    }

    public func delete(id: Record.ID) async throws {
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            throw RecordStoreError.notFound(id)
        }
        records.remove(at: index)
    }

    public func search(_ query: String) -> [Record] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return records }
        return records.filter { $0.name.lowercased().contains(trimmed) }
    }
}
```

- [ ] **Step 5: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter InMemoryRecordStoreTests`
Expected: 6 tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Package.swift Packages/Sources/StorageTestSupport Packages/Tests/StorageTestSupportTests
git commit -m "feat(storage-test-support): add InMemoryRecordStore for tests and previews

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: Storage — FileSystemPhotoStore

**Files:**
- Create: `Packages/Sources/Storage/FileSystemPhotoStore.swift`
- Create: `Packages/Tests/StorageTests/FileSystemPhotoStoreTests.swift`

- [ ] **Step 1: Write failing tests**

`Packages/Tests/StorageTests/FileSystemPhotoStoreTests.swift`:
```swift
import Testing
import Foundation
import CoreModels
@testable import Storage

@Suite struct FileSystemPhotoStoreTests {

    private func makeStore() throws -> (store: FileSystemPhotoStore, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-photos-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (FileSystemPhotoStore(rootURL: root), root)
    }

    @Test func saveWritesDataAndReturnsPhotoID() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let photoID = try await store.save(Data([0x1, 0x2, 0x3]))

        let fileURL = root.appendingPathComponent(photoID.filename)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func loadReturnsWrittenData() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let input = Data("hello".utf8)
        let photoID = try await store.save(input)

        let loaded = try await store.load(photoID)
        #expect(loaded == input)
    }

    @Test func loadReturnsNilForMissingID() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let missing = PhotoID(filename: "does-not-exist.heic")
        let result = try await store.load(missing)

        #expect(result == nil)
    }

    @Test func deleteRemovesFile() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let photoID = try await store.save(Data("hello".utf8))
        try await store.delete(photoID)

        let fileURL = root.appendingPathComponent(photoID.filename)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func deleteThrowsForMissingID() async throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let missing = PhotoID(filename: "ghost.heic")
        await #expect(throws: PhotoStoreError.notFound(missing)) {
            try await store.delete(missing)
        }
    }
}
```

- [ ] **Step 2: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter FileSystemPhotoStoreTests`
Expected: FAIL — `FileSystemPhotoStore` not found.

- [ ] **Step 3: Create FileSystemPhotoStore**

`Packages/Sources/Storage/FileSystemPhotoStore.swift`:
```swift
import Foundation
import CoreModels

public final class FileSystemPhotoStore: PhotoStore {

    private let rootURL: URL
    private let fileManager: FileManager

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    public func save(_ data: Data) async throws -> PhotoID {
        let filename = "\(UUID().uuidString).heic"
        let url = rootURL.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return PhotoID(filename: filename)
        } catch {
            throw PhotoStoreError.writeFailed(reason: String(describing: error))
        }
    }

    public func load(_ id: PhotoID) async throws -> Data? {
        let url = rootURL.appendingPathComponent(id.filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    public func delete(_ id: PhotoID) async throws {
        let url = rootURL.appendingPathComponent(id.filename)
        guard fileManager.fileExists(atPath: url.path) else {
            throw PhotoStoreError.notFound(id)
        }
        try fileManager.removeItem(at: url)
    }
}
```

- [ ] **Step 4: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter FileSystemPhotoStoreTests`
Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/Storage/FileSystemPhotoStore.swift Packages/Tests/StorageTests/FileSystemPhotoStoreTests.swift
git commit -m "feat(storage): add FileSystemPhotoStore

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 12: StorageTestSupport — InMemoryPhotoStore

**Files:**
- Create: `Packages/Sources/StorageTestSupport/InMemoryPhotoStore.swift`
- Create: `Packages/Tests/StorageTestSupportTests/InMemoryPhotoStoreTests.swift`

- [ ] **Step 1: Write failing tests**

`Packages/Tests/StorageTestSupportTests/InMemoryPhotoStoreTests.swift`:
```swift
import Testing
import Foundation
import CoreModels
@testable import StorageTestSupport

@Suite struct InMemoryPhotoStoreTests {

    @Test func saveAndLoadReturnsData() async throws {
        let store = InMemoryPhotoStore()
        let input = Data("abc".utf8)

        let id = try await store.save(input)
        let loaded = try await store.load(id)

        #expect(loaded == input)
    }

    @Test func loadReturnsNilForMissingID() async throws {
        let store = InMemoryPhotoStore()
        let missing = PhotoID(filename: "ghost.heic")
        let loaded = try await store.load(missing)
        #expect(loaded == nil)
    }

    @Test func deleteRemovesData() async throws {
        let store = InMemoryPhotoStore()
        let id = try await store.save(Data("abc".utf8))

        try await store.delete(id)

        let loaded = try await store.load(id)
        #expect(loaded == nil)
    }

    @Test func deleteThrowsForMissingID() async throws {
        let store = InMemoryPhotoStore()
        let ghost = PhotoID(filename: "ghost.heic")
        await #expect(throws: PhotoStoreError.notFound(ghost)) {
            try await store.delete(ghost)
        }
    }
}
```

- [ ] **Step 2: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter InMemoryPhotoStoreTests`
Expected: FAIL — `InMemoryPhotoStore` not found.

- [ ] **Step 3: Create InMemoryPhotoStore**

`Packages/Sources/StorageTestSupport/InMemoryPhotoStore.swift`:
```swift
import Foundation
import CoreModels

public actor InMemoryPhotoStore: PhotoStore {

    private var store: [PhotoID: Data] = [:]

    public init() {}

    public func save(_ data: Data) async throws -> PhotoID {
        let id = PhotoID(filename: "\(UUID().uuidString).heic")
        store[id] = data
        return id
    }

    public func load(_ id: PhotoID) async throws -> Data? {
        store[id]
    }

    public func delete(_ id: PhotoID) async throws {
        guard store.removeValue(forKey: id) != nil else {
            throw PhotoStoreError.notFound(id)
        }
    }
}
```

- [ ] **Step 4: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter InMemoryPhotoStoreTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/StorageTestSupport/InMemoryPhotoStore.swift Packages/Tests/StorageTestSupportTests/InMemoryPhotoStoreTests.swift
git commit -m "feat(storage-test-support): add InMemoryPhotoStore

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 13: Services module + MoonPhaseCalculator

**Files:**
- Modify: `Packages/Package.swift`
- Create: `Packages/Sources/Services/MoonPhaseCalculator.swift`
- Create: `Packages/Tests/ServicesTests/MoonPhaseCalculatorTests.swift`

- [ ] **Step 1: Add Services + ServicesTests to Package.swift**

Insert into `products`:
```swift
        .library(name: "Services", targets: ["Services"]),
```

Insert into `targets` (after StorageTestSupport entries):
```swift
        .target(
            name: "Services",
            dependencies: ["CoreModels"],
            path: "Sources/Services"
        ),
        .testTarget(
            name: "ServicesTests",
            dependencies: ["Services", "CoreModels"],
            path: "Tests/ServicesTests"
        ),
```

- [ ] **Step 2: Write failing moon-phase tests**

Moon phase calculation: we use the "Conway's simplified lunar phase" algorithm, accurate to within a day for dates between 1900 and 2199. Reference: `jd = julianDay(date); phase = (jd - 2451549.5) / 29.53058867; fraction = phase - floor(phase)`. Map fraction to one of 8 phases.

Known reference data (UTC):
- 2024-01-11 → new moon → fraction ≈ 0
- 2024-01-25 → full moon → fraction ≈ 0.5
- 2024-01-18 → first quarter → fraction ≈ 0.25
- 2024-02-02 → last/third quarter → fraction ≈ 0.75

`Packages/Tests/ServicesTests/MoonPhaseCalculatorTests.swift`:
```swift
import Testing
import Foundation
import CoreModels
@testable import Services

@Suite struct MoonPhaseCalculatorTests {

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)!
    }

    @Test func newMoonJanuary2024() {
        let phase = MoonPhaseCalculator.phase(at: date("2024-01-11T12:00:00Z"))
        #expect(phase == .newMoon)
    }

    @Test func fullMoonJanuary2024() {
        let phase = MoonPhaseCalculator.phase(at: date("2024-01-25T12:00:00Z"))
        #expect(phase == .fullMoon)
    }

    @Test func firstQuarterJanuary2024() {
        let phase = MoonPhaseCalculator.phase(at: date("2024-01-18T03:53:00Z"))
        #expect(phase == .firstQuarter)
    }

    @Test func lastQuarterFebruary2024() {
        let phase = MoonPhaseCalculator.phase(at: date("2024-02-02T23:18:00Z"))
        #expect(phase == .thirdQuarter)
    }

    @Test func phaseIsOneOfEightKnownCases() {
        let phase = MoonPhaseCalculator.phase(at: Date())
        #expect(MoonPhase.allCases.contains(phase))
    }
}
```

- [ ] **Step 3: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter MoonPhaseCalculatorTests`
Expected: FAIL — `MoonPhaseCalculator` not found.

- [ ] **Step 4: Implement MoonPhaseCalculator**

`Packages/Sources/Services/MoonPhaseCalculator.swift`:
```swift
import Foundation
import CoreModels

public enum MoonPhaseCalculator {

    /// Synodic month length in days (moon cycle from new to new).
    private static let synodicMonth = 29.530_588_67

    /// Julian day of a known new moon: 2000-01-06 18:14 UTC.
    private static let knownNewMoonJD = 2_451_550.1

    public static func phase(at date: Date) -> MoonPhase {
        let jd = julianDay(from: date)
        let cycles = (jd - knownNewMoonJD) / synodicMonth
        var fraction = cycles - cycles.rounded(.down)
        if fraction < 0 { fraction += 1 }

        switch fraction {
        case 0.0..<0.0625, 0.9375...1.0:
            return .newMoon
        case 0.0625..<0.1875:
            return .waxingCrescent
        case 0.1875..<0.3125:
            return .firstQuarter
        case 0.3125..<0.4375:
            return .waxingGibbous
        case 0.4375..<0.5625:
            return .fullMoon
        case 0.5625..<0.6875:
            return .waningGibbous
        case 0.6875..<0.8125:
            return .thirdQuarter
        case 0.8125..<0.9375:
            return .waningCrescent
        default:
            return .newMoon
        }
    }

    private static func julianDay(from date: Date) -> Double {
        // 2440587.5 = JD of 1970-01-01T00:00:00Z
        return 2_440_587.5 + date.timeIntervalSince1970 / 86_400.0
    }
}
```

- [ ] **Step 5: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter MoonPhaseCalculatorTests`
Expected: 5 tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Package.swift Packages/Sources/Services/MoonPhaseCalculator.swift Packages/Tests/ServicesTests/MoonPhaseCalculatorTests.swift
git commit -m "feat(services): add MoonPhaseCalculator

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 14: Services — TimeOfDayCalculator

**Files:**
- Create: `Packages/Sources/Services/TimeOfDayCalculator.swift`
- Create: `Packages/Tests/ServicesTests/TimeOfDayCalculatorTests.swift`

Time-of-day categories are coarse hour-of-day buckets. Without the user's location (the default when no permission), we use local timezone hour; with location we refine later. For Plan 1 we ship the hour-of-day version; location-aware sun calc can be a future refinement.

Hour → TimeOfDay mapping (local time):
- 04–05 → dawn
- 06–08 → sunrise
- 09–11 → midday
- 12–16 → midday
- 17–18 → sunset
- 19–20 → dusk
- 21–23 → night
- 00–03 → midnight

- [ ] **Step 1: Write failing tests**

`Packages/Tests/ServicesTests/TimeOfDayCalculatorTests.swift`:
```swift
import Testing
import Foundation
import CoreModels
@testable import Services

@Suite struct TimeOfDayCalculatorTests {

    private func date(hour: Int, minute: Int = 0, timeZone: String = "UTC") -> Date {
        var components = DateComponents()
        components.year = 2024
        components.month = 6
        components.day = 15
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: timeZone)
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    @Test func midnightReturnsMidnight() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 2), timeZone: "UTC") == .midnight)
    }

    @Test func earlyMorningReturnsDawn() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 5), timeZone: "UTC") == .dawn)
    }

    @Test func morningReturnsSunrise() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 7), timeZone: "UTC") == .sunrise)
    }

    @Test func middayReturnsMidday() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 13), timeZone: "UTC") == .midday)
    }

    @Test func earlyEveningReturnsSunset() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 18), timeZone: "UTC") == .sunset)
    }

    @Test func duskAfterSunset() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 20), timeZone: "UTC") == .dusk)
    }

    @Test func lateEveningReturnsNight() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 22), timeZone: "UTC") == .night)
    }

    @Test func boundaryMidnightIsMidnight() {
        #expect(TimeOfDayCalculator.category(at: date(hour: 0), timeZone: "UTC") == .midnight)
    }
}
```

- [ ] **Step 2: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter TimeOfDayCalculatorTests`
Expected: FAIL — `TimeOfDayCalculator` not found.

- [ ] **Step 3: Implement TimeOfDayCalculator**

`Packages/Sources/Services/TimeOfDayCalculator.swift`:
```swift
import Foundation
import CoreModels

public enum TimeOfDayCalculator {

    /// Bucket the date's wall-clock hour (in `timeZone`) into a TimeOfDay category.
    /// Plan 1 uses a coarse hour-of-day mapping independent of geographic location;
    /// refinement to true solar angles using CoreLocation is future work.
    public static func category(at date: Date, timeZone: String) -> TimeOfDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone) ?? TimeZone(secondsFromGMT: 0)!
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 0...3:   return .midnight
        case 4...5:   return .dawn
        case 6...8:   return .sunrise
        case 9...16:  return .midday
        case 17...18: return .sunset
        case 19...20: return .dusk
        case 21...23: return .night
        default:      return .midday
        }
    }
}
```

- [ ] **Step 4: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter TimeOfDayCalculatorTests`
Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/Services/TimeOfDayCalculator.swift Packages/Tests/ServicesTests/TimeOfDayCalculatorTests.swift
git commit -m "feat(services): add TimeOfDayCalculator (hour-of-day bucketing)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 15: Services — SystemMetadataGenerator

**Files:**
- Create: `Packages/Sources/Services/SystemMetadataGenerator.swift`
- Create: `Packages/Tests/ServicesTests/SystemMetadataGeneratorTests.swift`

- [ ] **Step 1: Write failing tests**

`Packages/Tests/ServicesTests/SystemMetadataGeneratorTests.swift`:
```swift
import Testing
import Foundation
import CoreModels
@testable import Services

@Suite struct SystemMetadataGeneratorTests {

    private func isoDate(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)!
    }

    @Test func metadataIncludesTimeOfDayAndMoonPhase() {
        let generator = SystemMetadataGenerator(timeZoneProvider: { "UTC" })
        let fullMoon = isoDate("2024-01-25T18:00:00Z")

        let metadata = generator.metadata(at: fullMoon, location: nil)

        #expect(metadata.moonPhase == .fullMoon)
        #expect(metadata.timeOfDay == .sunset)
    }

    @Test func metadataUsesLocationTimezoneWhenAvailable() {
        // Provider returns Tokyo's tz regardless; with location we expect Tokyo's wall clock.
        let generator = SystemMetadataGenerator(timeZoneProvider: { "Asia/Tokyo" })
        // 2024-01-25 18:00 UTC = 2024-01-26 03:00 JST → midnight bucket in Tokyo
        let fullMoon = isoDate("2024-01-25T18:00:00Z")

        let metadata = generator.metadata(
            at: fullMoon,
            location: LocationInfo(latitude: 35.68, longitude: 139.77, label: "Tokyo")
        )

        #expect(metadata.timeOfDay == .midnight)
        #expect(metadata.moonPhase == .fullMoon)
    }
}
```

- [ ] **Step 2: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter SystemMetadataGeneratorTests`
Expected: FAIL — `SystemMetadataGenerator` not found.

- [ ] **Step 3: Implement SystemMetadataGenerator**

`Packages/Sources/Services/SystemMetadataGenerator.swift`:
```swift
import Foundation
import CoreModels

public struct SystemMetadataGenerator: MetadataGenerator {

    private let timeZoneProvider: @Sendable () -> String

    public init(timeZoneProvider: @escaping @Sendable () -> String = { TimeZone.current.identifier }) {
        self.timeZoneProvider = timeZoneProvider
    }

    public func metadata(at date: Date, location: LocationInfo?) -> RecordMetadata {
        let timeZone = timeZoneProvider()
        return RecordMetadata(
            timeOfDay: TimeOfDayCalculator.category(at: date, timeZone: timeZone),
            moonPhase: MoonPhaseCalculator.phase(at: date)
        )
    }
}
```

Note: in Plan 1 we use the device's current timezone regardless of location. A future refinement would derive timezone from `location.latitude/longitude` via `TimeZone(identifier:)` or a lookup table. The `timeZoneProvider` parameter lets tests override this without relying on the host environment.

- [ ] **Step 4: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter SystemMetadataGeneratorTests`
Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/Services/SystemMetadataGenerator.swift Packages/Tests/ServicesTests/SystemMetadataGeneratorTests.swift
git commit -m "feat(services): compose SystemMetadataGenerator from calculators

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 16: ServicesTestSupport — FixedMetadataGenerator

**Files:**
- Modify: `Packages/Package.swift`
- Create: `Packages/Sources/ServicesTestSupport/FixedMetadataGenerator.swift`
- Create: `Packages/Tests/ServicesTestSupportTests/FixedMetadataGeneratorTests.swift`

- [ ] **Step 1: Add ServicesTestSupport to Package.swift**

Insert into `products`:
```swift
        .library(name: "ServicesTestSupport", targets: ["ServicesTestSupport"]),
```

Insert into `targets` (after ServicesTests entries):
```swift
        .target(
            name: "ServicesTestSupport",
            dependencies: ["CoreModels"],
            path: "Sources/ServicesTestSupport"
        ),
        .testTarget(
            name: "ServicesTestSupportTests",
            dependencies: ["ServicesTestSupport", "CoreModels"],
            path: "Tests/ServicesTestSupportTests"
        ),
```

- [ ] **Step 2: Write failing tests**

`Packages/Tests/ServicesTestSupportTests/FixedMetadataGeneratorTests.swift`:
```swift
import Testing
import Foundation
import CoreModels
@testable import ServicesTestSupport

@Suite struct FixedMetadataGeneratorTests {

    @Test func returnsSuppliedMetadataRegardlessOfInput() {
        let expected = RecordMetadata(timeOfDay: .dusk, moonPhase: .waxingCrescent)
        let generator = FixedMetadataGenerator(metadata: expected)

        let a = generator.metadata(at: Date(), location: nil)
        let b = generator.metadata(
            at: Date(timeIntervalSince1970: 0),
            location: LocationInfo(latitude: 0, longitude: 0, label: nil)
        )

        #expect(a == expected)
        #expect(b == expected)
    }
}
```

- [ ] **Step 3: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter FixedMetadataGeneratorTests`
Expected: FAIL — `FixedMetadataGenerator` not found.

- [ ] **Step 4: Implement FixedMetadataGenerator**

`Packages/Sources/ServicesTestSupport/FixedMetadataGenerator.swift`:
```swift
import Foundation
import CoreModels

public struct FixedMetadataGenerator: MetadataGenerator {

    private let metadata: RecordMetadata

    public init(metadata: RecordMetadata = RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)) {
        self.metadata = metadata
    }

    public func metadata(at date: Date, location: LocationInfo?) -> RecordMetadata {
        metadata
    }
}
```

- [ ] **Step 5: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter FixedMetadataGeneratorTests`
Expected: 1 test passes.

- [ ] **Step 6: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Package.swift Packages/Sources/ServicesTestSupport Packages/Tests/ServicesTestSupportTests
git commit -m "feat(services-test-support): add FixedMetadataGenerator

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 17: ServicesTestSupport — MockLocationService + StaticMotionService

**Files:**
- Create: `Packages/Sources/ServicesTestSupport/MockLocationService.swift`
- Create: `Packages/Sources/ServicesTestSupport/StaticMotionService.swift`
- Create: `Packages/Tests/ServicesTestSupportTests/MockLocationServiceTests.swift`
- Create: `Packages/Tests/ServicesTestSupportTests/StaticMotionServiceTests.swift`

- [ ] **Step 1: Write failing tests**

`Packages/Tests/ServicesTestSupportTests/MockLocationServiceTests.swift`:
```swift
import Testing
import Foundation
import CoreModels
@testable import ServicesTestSupport

@Suite struct MockLocationServiceTests {

    @Test func returnsConfiguredAuthorization() async {
        let service = MockLocationService(authorization: .denied)
        let result = await service.requestAuthorization()
        #expect(result == .denied)
    }

    @Test func returnsConfiguredLocation() async throws {
        let location = LocationInfo(latitude: 37.77, longitude: -122.41, label: "SF")
        let service = MockLocationService(authorization: .authorized, location: location)
        let result = try await service.currentLocation()
        #expect(result == location)
    }

    @Test func currentLocationThrowsWhenNotAuthorized() async {
        let service = MockLocationService(authorization: .denied, location: nil)
        await #expect(throws: LocationServiceError.notAuthorized) {
            _ = try await service.currentLocation()
        }
    }
}
```

`Packages/Tests/ServicesTestSupportTests/StaticMotionServiceTests.swift`:
```swift
import Testing
import Foundation
import CoreModels
@testable import ServicesTestSupport

@Suite struct StaticMotionServiceTests {

    @Test func publishesSingleStaticAttitude() async {
        let service = StaticMotionService(attitude: DeviceAttitude(pitch: 0.3, roll: -0.5))
        service.start()

        var received: DeviceAttitude?
        for await value in service.attitude {
            received = value
            service.stop()
            break
        }

        #expect(received?.pitch == 0.3)
        #expect(received?.roll == -0.5)
    }

    @Test func stopEndsTheStream() async {
        let service = StaticMotionService()
        service.start()
        service.stop()

        var iterator = service.attitude.makeAsyncIterator()
        let next = await iterator.next()
        // After stop the stream should end (yield nil)
        #expect(next == nil || next == DeviceAttitude.zero)
    }
}
```

- [ ] **Step 2: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter ServicesTestSupportTests`
Expected: FAIL — types not found.

- [ ] **Step 3: Implement MockLocationService**

`Packages/Sources/ServicesTestSupport/MockLocationService.swift`:
```swift
import Foundation
import CoreModels

public final class MockLocationService: LocationService, @unchecked Sendable {

    private let authorization: LocationAuthorization
    private let location: LocationInfo?

    public init(
        authorization: LocationAuthorization = .authorized,
        location: LocationInfo? = LocationInfo(latitude: 37.7749, longitude: -122.4194, label: "San Francisco")
    ) {
        self.authorization = authorization
        self.location = location
    }

    public func requestAuthorization() async -> LocationAuthorization {
        authorization
    }

    public func currentLocation() async throws -> LocationInfo? {
        if authorization == .denied { throw LocationServiceError.notAuthorized }
        return location
    }
}
```

- [ ] **Step 4: Implement StaticMotionService**

`Packages/Sources/ServicesTestSupport/StaticMotionService.swift`:
```swift
import Foundation
import CoreModels

public final class StaticMotionService: MotionService, @unchecked Sendable {

    private let fixedAttitude: DeviceAttitude
    private var continuation: AsyncStream<DeviceAttitude>.Continuation?
    public let attitude: AsyncStream<DeviceAttitude>

    public init(attitude: DeviceAttitude = .zero) {
        self.fixedAttitude = attitude
        var continuation: AsyncStream<DeviceAttitude>.Continuation!
        self.attitude = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    public func start() {
        continuation?.yield(fixedAttitude)
    }

    public func stop() {
        continuation?.finish()
        continuation = nil
    }
}
```

- [ ] **Step 5: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter ServicesTestSupportTests`
Expected: 3 MockLocationService tests + 2 StaticMotionService tests + 1 FixedMetadataGenerator test from Task 16 = 6 tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/ServicesTestSupport/MockLocationService.swift Packages/Sources/ServicesTestSupport/StaticMotionService.swift Packages/Tests/ServicesTestSupportTests/MockLocationServiceTests.swift Packages/Tests/ServicesTestSupportTests/StaticMotionServiceTests.swift
git commit -m "feat(services-test-support): add MockLocationService and StaticMotionService

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 18: Services — CoreLocationService

**Files:**
- Create: `Packages/Sources/Services/CoreLocationService.swift`
- Create: `Packages/Tests/ServicesTests/CoreLocationServiceTests.swift`

We wrap `CLLocationManager` behind an internal protocol so the authorization + location-update flow can be tested without needing a device.

- [ ] **Step 1: Write failing tests**

`Packages/Tests/ServicesTests/CoreLocationServiceTests.swift`:
```swift
import Testing
import Foundation
import CoreLocation
import CoreModels
@testable import Services

@Suite struct CoreLocationServiceTests {

    @Test func requestAuthorizationReturnsAuthorizedWhenManagerGrants() async {
        let manager = FakeLocationManager()
        manager.nextAuthorizationStatus = .authorizedWhenInUse

        let service = CoreLocationService(managerFactory: { manager })
        let result = await service.requestAuthorization()

        #expect(result == .authorized)
    }

    @Test func requestAuthorizationReturnsDeniedWhenManagerDenies() async {
        let manager = FakeLocationManager()
        manager.nextAuthorizationStatus = .denied

        let service = CoreLocationService(managerFactory: { manager })
        let result = await service.requestAuthorization()

        #expect(result == .denied)
    }

    @Test func currentLocationThrowsWhenNotAuthorized() async {
        let manager = FakeLocationManager()
        manager.nextAuthorizationStatus = .denied

        let service = CoreLocationService(managerFactory: { manager })
        await #expect(throws: LocationServiceError.notAuthorized) {
            _ = try await service.currentLocation()
        }
    }

    @Test func currentLocationReturnsLatestLocation() async throws {
        let manager = FakeLocationManager()
        manager.nextAuthorizationStatus = .authorizedWhenInUse
        manager.locationToDeliver = CLLocation(latitude: 37.77, longitude: -122.41)

        let service = CoreLocationService(managerFactory: { manager })
        let result = try await service.currentLocation()

        #expect(result?.latitude == 37.77)
        #expect(result?.longitude == -122.41)
    }
}

// MARK: - Fakes

final class FakeLocationManager: LocationManagerProtocol, @unchecked Sendable {
    weak var delegate: CLLocationManagerDelegate?
    var nextAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var locationToDeliver: CLLocation?

    var authorizationStatus: CLAuthorizationStatus { nextAuthorizationStatus }

    func requestWhenInUseAuthorization() {
        // Simulate async delegate callback
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.locationManagerDidChangeAuthorization?(CLLocationManager())
        }
    }

    func requestLocation() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let loc = self.locationToDeliver else { return }
            self.delegate?.locationManager?(CLLocationManager(), didUpdateLocations: [loc])
        }
    }
}
```

- [ ] **Step 2: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter CoreLocationServiceTests`
Expected: FAIL — `CoreLocationService`, `LocationManagerProtocol` not found.

- [ ] **Step 3: Implement CoreLocationService**

`Packages/Sources/Services/CoreLocationService.swift`:
```swift
import Foundation
import CoreLocation
import CoreModels

// MARK: - Internal protocol seam for testing

public protocol LocationManagerProtocol: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func requestLocation()
}

extension CLLocationManager: LocationManagerProtocol {}

// MARK: - Service

public final class CoreLocationService: NSObject, LocationService, CLLocationManagerDelegate, @unchecked Sendable {

    private let manager: LocationManagerProtocol
    private var authContinuation: CheckedContinuation<LocationAuthorization, Never>?
    private var locationContinuation: CheckedContinuation<LocationInfo?, Error>?

    public init(managerFactory: () -> LocationManagerProtocol = { CLLocationManager() }) {
        self.manager = managerFactory()
        super.init()
        self.manager.delegate = self
    }

    public func requestAuthorization() async -> LocationAuthorization {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                self.authContinuation = continuation
                self.manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            return .notDetermined
        }
    }

    public func currentLocation() async throws -> LocationInfo? {
        let auth = await requestAuthorization()
        guard auth == .authorized else {
            throw LocationServiceError.notAuthorized
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            self.manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth: LocationAuthorization = {
            switch self.manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse: return .authorized
            case .denied, .restricted: return .denied
            case .notDetermined: return .notDetermined
            @unknown default: return .notDetermined
            }
        }()
        authContinuation?.resume(returning: auth)
        authContinuation = nil
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
            return
        }
        let info = LocationInfo(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            label: nil
        )
        locationContinuation?.resume(returning: info)
        locationContinuation = nil
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}
```

- [ ] **Step 4: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter CoreLocationServiceTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/Services/CoreLocationService.swift Packages/Tests/ServicesTests/CoreLocationServiceTests.swift
git commit -m "feat(services): add CoreLocationService with testable CLLocationManager wrapper

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 19: Services — CoreMotionService with low-pass smoothing

**Files:**
- Create: `Packages/Sources/Services/CoreMotionService.swift`
- Create: `Packages/Tests/ServicesTests/CoreMotionSmoothingTests.swift`

The production motion service uses `CMMotionManager`. Because `CMMotionManager` isn't readily fake-able without heavy indirection, we test the smoothing math separately as a pure function, and leave integration with `CMMotionManager` uncovered by unit tests (visual QA covers it in later plans).

- [ ] **Step 1: Write failing tests for smoothing math**

`Packages/Tests/ServicesTests/CoreMotionSmoothingTests.swift`:
```swift
import Testing
import Foundation
import CoreModels
@testable import Services

@Suite struct CoreMotionSmoothingTests {

    @Test func smoothedValueStartsFromFirstSample() {
        let smoother = AttitudeLowPass(alpha: 0.1)
        let out = smoother.smooth(DeviceAttitude(pitch: 1.0, roll: -1.0))
        #expect(out.pitch == 1.0)
        #expect(out.roll == -1.0)
    }

    @Test func smoothedValueTrailsRawSamples() {
        let smoother = AttitudeLowPass(alpha: 0.1)
        _ = smoother.smooth(DeviceAttitude(pitch: 0, roll: 0))
        let out = smoother.smooth(DeviceAttitude(pitch: 1.0, roll: 1.0))
        // Large alpha = 0.1 → new sample contributes 10%, old state 90%
        #expect(out.pitch > 0.0 && out.pitch < 1.0)
        #expect(out.roll > 0.0 && out.roll < 1.0)
    }

    @Test func smoothedValueClampsToRange() {
        let smoother = AttitudeLowPass(alpha: 0.5)
        let out = smoother.smooth(DeviceAttitude(pitch: 10.0, roll: -10.0))
        #expect(out.pitch == 1.0)
        #expect(out.roll == -1.0)
    }

    @Test func repeatedSamplesConvergeToTarget() {
        let smoother = AttitudeLowPass(alpha: 0.3)
        _ = smoother.smooth(.zero)
        var last = DeviceAttitude.zero
        for _ in 0..<100 {
            last = smoother.smooth(DeviceAttitude(pitch: 0.8, roll: 0.8))
        }
        #expect(abs(last.pitch - 0.8) < 0.001)
        #expect(abs(last.roll - 0.8) < 0.001)
    }
}
```

- [ ] **Step 2: Verify tests fail**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter CoreMotionSmoothingTests`
Expected: FAIL — `AttitudeLowPass` not found.

- [ ] **Step 3: Implement CoreMotionService + AttitudeLowPass**

`Packages/Sources/Services/CoreMotionService.swift`:
```swift
import Foundation
import CoreMotion
import CoreModels

// MARK: - Pure smoothing (unit-tested)

public final class AttitudeLowPass: @unchecked Sendable {

    private let alpha: Double
    private var state: DeviceAttitude?

    public init(alpha: Double) {
        self.alpha = alpha
    }

    @discardableResult
    public func smooth(_ raw: DeviceAttitude) -> DeviceAttitude {
        let clamped = raw.clamped()
        guard let previous = state else {
            state = clamped
            return clamped
        }
        let mixed = DeviceAttitude(
            pitch: previous.pitch + alpha * (clamped.pitch - previous.pitch),
            roll: previous.roll + alpha * (clamped.roll - previous.roll)
        )
        state = mixed
        return mixed
    }
}

// MARK: - Production service

public final class CoreMotionService: MotionService, @unchecked Sendable {

    private let manager = CMMotionManager()
    private let smoother = AttitudeLowPass(alpha: 0.1)
    private var continuation: AsyncStream<DeviceAttitude>.Continuation?
    public let attitude: AsyncStream<DeviceAttitude>

    public init() {
        var continuation: AsyncStream<DeviceAttitude>.Continuation!
        self.attitude = AsyncStream { continuation = $0 }
        self.continuation = continuation
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
    }

    public func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            // Normalize roll/pitch from radians to -1…1
            let raw = DeviceAttitude(
                pitch: motion.attitude.pitch / (.pi / 2),
                roll: motion.attitude.roll / (.pi / 2)
            )
            let smoothed = self.smoother.smooth(raw)
            self.continuation?.yield(smoothed)
        }
    }

    public func stop() {
        manager.stopDeviceMotionUpdates()
        continuation?.finish()
        continuation = nil
    }
}
```

- [ ] **Step 4: Verify tests pass**

Run: `cd /Users/adam/Projects/cc/Packages && swift test --filter CoreMotionSmoothingTests`
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/adam/Projects/cc
git add Packages/Sources/Services/CoreMotionService.swift Packages/Tests/ServicesTests/CoreMotionSmoothingTests.swift
git commit -m "feat(services): add CoreMotionService with tested low-pass smoothing

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 20: Final pass — run full suite, verify clean build

**Files:** none

- [ ] **Step 1: Run full test suite**

Run: `cd /Users/adam/Projects/cc/Packages && swift test`

Expected: all tests green. Rough expected counts (may drift if earlier tasks added more tests):
- CoreModelsTests: ~22
- StorageTests: ~15
- StorageTestSupportTests: ~10
- ServicesTests: ~19
- ServicesTestSupportTests: ~6

Total ~70+ tests, all passing.

- [ ] **Step 2: Verify release-mode build also compiles**

Run: `cd /Users/adam/Projects/cc/Packages && swift build -c release`
Expected: `Build complete!`

- [ ] **Step 3: Verify Xcode app still builds**

Run: `xcodebuild -project /Users/adam/Projects/cc/CasualContacts.xcodeproj -scheme CasualContacts -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **` (the app target is still the Xcode-generated stub — it doesn't import the package yet; Plan 3 wires them together).

If the build fails because the package isn't linked to the Xcode project: that's fine at this point — it will be wired up in Plan 2/3. Verify by running `swift test` in the Packages directory; that's the authoritative signal for Plan 1.

- [ ] **Step 4: Commit any remaining work**

Check `git status`. If clean, done. If there's anything uncommitted, inspect, commit with a meaningful message, and stop.

```bash
cd /Users/adam/Projects/cc
git status
```

Expected: `nothing to commit, working tree clean`.

---

## What's done

Plan 1 produces:
- A working Swift Package with `CoreModels`, `Storage`, `StorageTestSupport`, `Services`, `ServicesTestSupport` modules
- `@Observable` `SwiftDataRecordStore` + `InMemoryRecordStore` implementing the `RecordStore` protocol
- `FileSystemPhotoStore` + `InMemoryPhotoStore` implementing `PhotoStore`
- `SystemMetadataGenerator` (with `MoonPhaseCalculator` + `TimeOfDayCalculator`) + `FixedMetadataGenerator`
- `CoreLocationService` (testable via `LocationManagerProtocol`) + `MockLocationService`
- `CoreMotionService` (with unit-tested `AttitudeLowPass` smoothing) + `StaticMotionService`
- 70+ passing tests covering the data + service layer

## What's next

Plan 2 — Design System & Visuals:
- `DesignSystem` module (colors, typography, reusable primitives)
- `Tools/SVGToSwift` build-time asset pipeline
- `Visuals` module: Gradients, Guilloche Rotation, Guilloche Blend, Moon, Zodiac, Holograms, Photo treatments, `CardView` composition
- Snapshot testing infrastructure
