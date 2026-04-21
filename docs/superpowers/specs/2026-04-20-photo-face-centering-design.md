# Photo Face-Centering — Design Spec

**Date:** 2026-04-20
**Related canonical docs:** `docs/DESIGN.md` §"Photo treatments", `docs/superpowers/specs/2026-04-17-casual-contacts-design.md`

## 1. Background

When a user picks or captures a photo in the create flow, it is persisted by `FileSystemPhotoStore` and rendered through `PhotoLayer` (`Packages/Sources/Visuals/Layers/PhotoLayer.swift`), which calls `.resizable().scaledToFill()`. `scaledToFill` hard-centers on the image's geometric center. If the subject's face sits off-center (common for casual photos), the face gets clipped by the card's aspect ratio — undermining the whole memory-association purpose of the card.

This spec adds automatic face detection at photo-selection time and composes the photo so the detected face sits at the center of the render frame, in both the create-flow preview and every `CardView` that displays the record.

## 2. Goals

- Detect the largest face in a selected photo and persist a normalized focus point alongside the record.
- In the create flow, show a spinner while detection runs; render the photo (already face-centered) once detection completes.
- In `CardView` (list rows, detail scenes), render the stored photo so the face sits at the container's center, clamped to image bounds so we never reveal empty margin.
- Preserve the original photo bytes — no destructive cropping at save time.
- Gracefully fall back to centered rendering when no face is detected or detection fails.

## 3. Non-goals / deferred

- **Backfill for existing records.** Records saved before this change keep `photoFocus = nil` and render centered as today. No migration job.
- **Landmark-based centering.** We use `VNDetectFaceRectanglesRequest` (bounding box), not `VNDetectFaceLandmarksRequest` (eyes/nose/mouth). Simpler, faster, and good enough for the card crop.
- **Manual re-adjustment UI.** No drag-to-reposition in v1. If the auto-result looks wrong, the user deletes and re-picks.
- **Multi-face UX.** We pick the largest face silently; no chooser.
- **Saliency fallback for non-portrait photos.** If no face is detected, we center. We don't fall back to attention-based saliency.
- **Non-card photo surfaces.** No changes to future full-screen photo views or recommended-section avatars — they can read `photoFocus` when built.

## 4. Architecture

### 4.1 New type — `NormalizedPoint` (`CoreModels`)

**New:** `Packages/Sources/CoreModels/Types/NormalizedPoint.swift`

```swift
public struct NormalizedPoint: Hashable, Codable, Sendable {
    public let x: Double  // 0...1, image-space, origin top-left
    public let y: Double  // 0...1, image-space, origin top-left

    public init(x: Double, y: Double) { … }  // clamps to [0,1]

    public static let center = NormalizedPoint(x: 0.5, y: 0.5)
}
```

Top-left origin (matches UIKit/SwiftUI image coordinates). The Vision implementation converts from Vision's bottom-left-origin coordinates before returning.

### 4.2 New protocol — `FaceDetectionService` (`CoreModels`)

**New:** `Packages/Sources/CoreModels/Protocols/FaceDetectionService.swift`

```swift
public protocol FaceDetectionService: Sendable {
    /// Returns a normalized focus point for the largest face in `imageData`,
    /// or nil if no face is detected or detection fails. Callers treat nil as
    /// "render centered" — the service never throws.
    func focusPoint(in imageData: Data) async -> NormalizedPoint?
}
```

### 4.3 Real implementation — `VisionFaceDetectionService` (`Services`)

**New:** `Packages/Sources/Services/VisionFaceDetectionService.swift`

- `#if canImport(Vision) && !os(macOS)` — gated identically to `CoreMotionService`.
- Uses `VNDetectFaceRectanglesRequest`.
- Picks the observation with the largest `boundingBox.width * boundingBox.height`.
- Converts `boundingBox` (Vision: bottom-left origin, normalized) → `NormalizedPoint` (top-left origin, normalized) at the bounding-box **center**.
- Swallows any thrown error → returns nil.
- Runs the request on a background queue; the async method suspends on the callback.

A macOS stub returns nil for every call so the package builds for host-side testing (matching the `CoreMotion`/`CLAuthorizationStatus` pattern).

### 4.4 Test doubles — `StaticFaceDetectionService` (`ServicesTestSupport`)

**New:** `Packages/Sources/ServicesTestSupport/StaticFaceDetectionService.swift`

```swift
public final class StaticFaceDetectionService: FaceDetectionService, @unchecked Sendable {
    public var result: NormalizedPoint?
    public var delay: Duration = .zero           // lets tests exercise the spinner state
    public private(set) var callCount = 0

    public init(result: NormalizedPoint? = .center) { … }
    public func focusPoint(in imageData: Data) async -> NormalizedPoint? { … }
}
```

### 4.5 Data model additions

**Changed:** `CoreModels/Types/Record.swift`

Add `public var photoFocus: NormalizedPoint?` as a mutable field. Nil means "render centered" (legacy records and records where detection failed).

**Changed:** `CoreModels/Types/RecordDraft.swift`

Add `photoFocus: NormalizedPoint?` so the create flow can hand the detected focus to the store without a second detection pass at persist time.

**Changed:** `Storage/PersistedRecord.swift`

Add two scalar fields — same lightweight-migration pattern as `guillocheShapeRaw`:

```swift
public var photoFocusX: Double?
public var photoFocusY: Double?
```

Existing records decode these as nil → `Record.photoFocus` = nil → centered render. No explicit migration step needed; SwiftData treats them as optional additions.

**Changed:** `Storage/SwiftDataRecordStore.swift`

Map `photoFocus` ↔ `(photoFocusX, photoFocusY)` in both directions. Drop both fields when the draft's focus is nil.

### 4.6 Create flow — detection with spinner

**Changed:** `FeatureCreate/CreateRecordModel.swift`

Add:

```swift
public enum PhotoState: Sendable {
    case none
    case detecting(Data)               // spinner shown; no photo in preview
    case ready(Data, NormalizedPoint?) // rendered face-centered (or centered if nil)
}

public private(set) var photoState: PhotoState = .none

public func setPhoto(_ data: Data, using service: any FaceDetectionService) {
    photoState = .detecting(data)
    Task { @MainActor in
        let focus = await service.focusPoint(in: data)
        // Ignore late results if the user has since cleared or replaced the photo.
        if case .detecting(let current) = photoState, current == data {
            photoState = .ready(data, focus)
        }
    }
}
```

Derived properties:

- `photoData`: returns the `Data` for `.detecting` and `.ready`; nil for `.none`.
- `photoFocus`: returns the focus only for `.ready(_, focus)`.
- `isDetectingPhoto`: true for `.detecting`.
- `isSaveable`: existing name-non-empty rule **AND** `!isDetectingPhoto` — we block Save while detection is running so the persisted record always reflects the detection result.

`draft` includes `photoFocus`:

```swift
RecordDraft(
    name: name,
    description: description,
    photo: photoData,
    photoFocus: photoFocus,
    location: location,
    zodiacSign: randomZodiacSign,
    guillocheShape: guillocheShape
)
```

`previewRecord` threads `photoFocus` into `Record.photoFocus` so the backdrop preview uses the same centering as the eventual persisted card.

**Changed:** `FeatureCreate/CreateRecordScene.swift`

- Pass the `FaceDetectionService` in via a new `faceDetectionService:` init parameter (wired from `AppEnvironment` at the call site in `AppFeature/RootScene.swift`).
- Replace the direct `model.photoData = data` assignments (PhotosPicker `onChange` and `CameraPicker` `onCapture`) with `model.setPhoto(data, using: faceDetectionService)`.

**Changed:** `FeatureCreate/CreateFormOverlay.swift`

Replace the current `addPhotoButton` with a state-driven view:

- `.none`: existing `+ Add Photo` button.
- `.detecting`: a compact `ProgressView` in the same slot, label replaced with "Analyzing…" (or similar). Tappable no-op (disabled).
- `.ready`: `+ Add Photo` is hidden (photo is now visible in the card backdrop behind the form); if we want a re-pick affordance, we can surface a small "Change photo" link here — keep the slot visually coherent across states.

The `SaveButton` already binds to `model.isSaveable`, which now includes the detection gate.

**Changed:** `Visuals/CardBackdrop.swift`

Only render `PhotoLayer` when the model/record is actually ready to show a photo. For `CreateRecordScene`, `previewRecord.photoID` is nil during `.detecting` (keep the current "nil during detection" behavior by only setting `previewPhotoID` in `.ready`), so `CardBackdrop` naturally omits the photo layer until detection completes.

### 4.7 Render change — `PhotoLayer` focus offset

**Changed:** `Visuals/Layers/PhotoLayer.swift`

Add a `focus: NormalizedPoint?` init parameter. When nil, behavior is unchanged (`.scaledToFill()` center-crops — byte-for-byte identical to today).

When non-nil, wrap the existing content in a `GeometryReader` and compute an `.offset` so the focus point sits at the container center, clamped to image bounds:

```
// Pseudocode — real implementation needs image aspect ratio; we pass it in or
// read it from the UIImage during decode.
let containerAspect = geo.size.width / geo.size.height
let imageAspect = imageSize.width / imageSize.height

// scaledToFill: the image covers the container; one axis overflows.
let (scaledW, scaledH) = imageAspect > containerAspect
    ? (geo.size.height * imageAspect, geo.size.height)   // wider overflow on x
    : (geo.size.width, geo.size.width / imageAspect)     // taller overflow on y

let desiredDX = (0.5 - focus.x) * scaledW
let desiredDY = (0.5 - focus.y) * scaledH

let maxDX = max(0, (scaledW - geo.size.width) / 2)
let maxDY = max(0, (scaledH - geo.size.height) / 2)

let dx = min(max(desiredDX, -maxDX), maxDX)
let dy = min(max(desiredDY, -maxDY), maxDY)
```

This requires knowing the image's pixel dimensions. Options:

- (a) Pass `imageSize: CGSize?` alongside `image: Image` into `PhotoLayer` (caller responsibility).
- (b) Decode the `UIImage` at the call site and pass both.

We'll use (a). `PhotoCache` already decodes `UIImage` → `Image`; extend it to cache `(Image, CGSize)` and expose an `imageSize(for:)` accessor. `CardView`/`CardBackdrop` then pass `imageSize` to `PhotoLayer` alongside the existing `Image`. For the create flow, `CreateRecordScene.photoImage` similarly returns `(Image, CGSize)?` derived from `UIImage(data:)`.

`.accessibilityReduceTransparency` and the `Style.card` / `.recommended` branches are untouched — the offset is applied identically to both.

### 4.8 Wiring — `AppEnvironment`

**Changed:** `AppFeature/AppEnvironment.swift`

Add:

```swift
public let faceDetectionService: any FaceDetectionService
```

Production wiring: `VisionFaceDetectionService()`.
UI-test reset wiring: `StaticFaceDetectionService(result: .center)` so UI tests don't depend on Vision.
Pass through to `CreateRecordScene` at the call site.

## 5. Data flow

```
User picks photo in PhotosPicker / CameraPicker
        │
        ▼
CreateRecordScene.onCapture / photoItem.onChange
        │
        ▼
model.setPhoto(data, using: faceDetectionService)
        │
        ├──► photoState = .detecting(data)         → UI shows spinner; photo layer hidden
        │
        ▼ (async)
service.focusPoint(in: data)
        │
        ▼
photoState = .ready(data, focus)                    → UI shows photo; PhotoLayer offsets by focus
        │
        ▼ (user taps Save)
draft { photo: data, photoFocus: focus, … }
        │
        ▼
RecordStore.create(draft)
        │
        ▼
SwiftDataRecordStore persists (photoFilename, photoFocusX, photoFocusY)
        │
        ▼
List / detail render Record { photoFocus } → PhotoLayer shifts to face center
```

## 6. Testing strategy

- **`NormalizedPoint`** — unit tests for clamping (inputs outside [0,1] → clamped), Codable round-trip.
- **`VisionFaceDetectionService`** (iOS simulator only, `#if canImport(Vision)`):
  - Known-face fixture image → non-nil point near the expected face center (±0.05 tolerance).
  - No-face fixture image (e.g., a landscape) → nil.
  - Malformed bytes (empty `Data`) → nil (no throw).
  - Multi-face fixture → returns the largest face's center.
  - Test fixtures live in `Packages/Tests/ServicesTests/Fixtures/`. Keep them small (<100 KB each) and CC0 or self-captured.
- **`StaticFaceDetectionService`** — trivial; used primarily to drive upstream tests.
- **`CreateRecordModel`** with `StaticFaceDetectionService(result: NormalizedPoint(x: 0.3, y: 0.4), delay: .milliseconds(50))`:
  - After `setPhoto`, `isDetectingPhoto == true`, `isSaveable == false`, `previewRecord.photoFocus == nil`.
  - After the detection await completes, `isDetectingPhoto == false`, `photoFocus == NormalizedPoint(0.3, 0.4)`, `draft.photoFocus` matches, `isSaveable == true` (assuming name non-empty).
  - Replacing a photo mid-detection discards the stale result (second `setPhoto` wins even if the first detection completes later).
- **`PhotoLayer` offset math** — pure function test on the clamp logic extracted to a helper; plus a snapshot test at a known focus point (`0.2, 0.2`) and container/image sizes, verifying the shift is in the expected direction vs. the nil-focus baseline.
- **`SwiftDataRecordStore`** — round-trip a `RecordDraft` with and without `photoFocus`; verify `photoFocus == nil` on legacy rows that lack the new columns.
- **Snapshot (`VisualsTests/CardSnapshotTests`)** — re-record two new cases: card with photo + focus at (0.2, 0.2), and card with photo + focus nil (should match the existing baseline byte-for-byte).

## 7. Accessibility

`PhotoLayer` already calls `.accessibilityHidden(true)`. The spinner in `CreateFormOverlay` during `.detecting` should have a VoiceOver label ("Analyzing photo") and be part of the accessibility tree so users know why Save is temporarily disabled.

`ReduceMotion` / `ReduceTransparency`: no new behavior. The existing `.blendMode(.luminosity)` / reduce-transparency branch inside `PhotoLayer` wraps the same content that now carries the offset — unchanged visually for reduce-transparency users aside from the intended face centering.

## 8. Risks & open calls

- **Image-size plumbing.** `PhotoCache` currently returns a bare `Image`; we need the underlying pixel size for the offset math. Extending the cache is straightforward but adds a field and touches every caller (three sites: `CardView`, `CardBackdrop`, `CreateRecordScene`).
- **Vision latency.** `VNDetectFaceRectanglesRequest` on a ~3 MP photo usually returns in <150 ms on-device. The spinner state is short but exists — acceptable tradeoff for no surprise clipping.
- **Detection failure silence.** If detection throws or returns zero observations, we save `photoFocus = nil`. Users see the photo unchanged (centered). No error UI.
- **Re-picking photos.** The `setPhoto` discard-stale-result guard relies on `Data` equality; if the user re-picks the same photo mid-detection (same bytes), we'll still accept it. Harmless — the focus will be the same.

## 9. Files touched

- **Added**
  - `Packages/Sources/CoreModels/Types/NormalizedPoint.swift`
  - `Packages/Sources/CoreModels/Protocols/FaceDetectionService.swift`
  - `Packages/Sources/Services/VisionFaceDetectionService.swift`
  - `Packages/Sources/ServicesTestSupport/StaticFaceDetectionService.swift`
  - Tests: `Packages/Tests/CoreModelsTests/NormalizedPointTests.swift`, `Packages/Tests/ServicesTests/VisionFaceDetectionServiceTests.swift`, plus new cases in existing test files.
- **Changed**
  - `Packages/Sources/CoreModels/Types/Record.swift` — `+photoFocus`
  - `Packages/Sources/CoreModels/Types/RecordDraft.swift` — `+photoFocus`
  - `Packages/Sources/Storage/PersistedRecord.swift` — `+photoFocusX/Y`
  - `Packages/Sources/Storage/SwiftDataRecordStore.swift` — mapping
  - `Packages/Sources/Visuals/Layers/PhotoLayer.swift` — `+focus/imageSize`, offset math
  - `Packages/Sources/Visuals/CardBackdrop.swift` — pass focus/imageSize through
  - `Packages/Sources/Visuals/CardView.swift` — same plumbing
  - `Packages/Sources/AppFeature/PhotoCache.swift` — store + expose image size
  - `Packages/Sources/AppFeature/AppEnvironment.swift` — `+faceDetectionService`
  - `Packages/Sources/AppFeature/RootScene.swift` — inject `faceDetectionService` into `CreateRecordScene`
  - `Packages/Sources/FeatureCreate/CreateRecordModel.swift` — `photoState`, `setPhoto(_:using:)`, `isSaveable` gate
  - `Packages/Sources/FeatureCreate/CreateRecordScene.swift` — accept service; call `setPhoto`
  - `Packages/Sources/FeatureCreate/CreateFormOverlay.swift` — spinner state
  - `Packages/Sources/FeatureDetail/LargeDetailScene.swift`, `MediumDetailSheet.swift` — image-size plumbing if needed
  - `Packages/Sources/FeatureList/RecordsListScene.swift` — image-size plumbing if needed
