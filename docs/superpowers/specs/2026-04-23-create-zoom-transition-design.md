# Create Zoom Transition — Design

Date: 2026-04-23
Status: Approved
Branch: `feature/create-zoom-transition`

## Summary

Wire iOS 18's zoom navigation transition so tapping the `+` button on the list screen morphs it into the Create sheet. Build the plumbing generically (environment-carried namespace + string-keyed source IDs) so additional zoom sources can be added with a single call-site modifier.

Reference: [WWDC24 — Enhance your UI animations and transitions](https://developer.apple.com/videos/play/wwdc2024/10145/), [`.matchedTransitionSource`](https://developer.apple.com/documentation/swiftui/customizabletoolbarcontent/matchedtransitionsource%28id%3Ain%3A%29), [`.navigationTransition(.zoom(...))`](https://developer.apple.com/documentation/swiftui/navigationtransition).

## Goal

Primary:
- Tapping `+` on `RecordsListScene` → Create sheet presents with iOS-18 zoom transition.

Secondary:
- Mechanism is reusable: adding a second zoom source (e.g. card → medium detail) should be two one-line modifiers, not more plumbing.

Non-goals:
- Applying zoom to any screen other than the `+` → Create path in this change.
- Changing the sheet presentation style, detents, or corner radius.
- Designing any new interaction, animation curve, or fallback for reduced motion beyond what SwiftUI gives us for free.

## Architecture

The zoom transition needs a `Namespace.ID` shared between source (`.matchedTransitionSource(id:in:)`) and destination (`.navigationTransition(.zoom(sourceID:in:))`). The challenge is our module boundaries:

- `FeatureList` declares the `+` button. It does **not** import `AppFeature`.
- `AppFeature` owns `RootScene` where the sheet is presented.

A shared location both can see is `DesignSystem`. It has no SwiftUI/UIKit surface conflicts and is already imported by every feature module.

### Pieces

1. **`DesignSystem/ZoomTransition.swift`** (new, ~40 lines)
   - `public struct ZoomSourceID: Hashable, Sendable { public let rawValue: String }`
     - V1 defines a single constant `public static let createButton = ZoomSourceID(rawValue: "createButton")` directly on the type inside `DesignSystem`.
     - When more sources are added, the same pattern (static constants on `ZoomSourceID`) is used. Revisit if we end up with >3 IDs; might move them to a separate registry file.
   - `EnvironmentKey` for an optional `Namespace.ID` (nil default so previews and tests work).
   - `View.zoomSource(_ id: ZoomSourceID)` — reads the env namespace; if present, applies `.matchedTransitionSource(id:in:)`; if absent, returns view unchanged.
   - `View.zoomDestination(_ id: ZoomSourceID)` — reads the env namespace; if present, applies `.navigationTransition(.zoom(sourceID:in:))`; if absent, returns view unchanged.
   - iOS-only call gated by `#if os(iOS)`. On macOS the helpers return the view as-is.

2. **`AppFeature/RootScene.swift`**
   - Add `@Namespace private var zoomNS` on `RootScene`.
   - Inject with `.environment(\.zoomNamespace, zoomNS)` on the root body.
   - Attach `.zoomDestination(.createButton)` inside the `.sheet(isPresented: $router.showingCreate)` closure, on `CreateRecordScene`.

3. **`FeatureList/RecordsListScene.swift`**
   - One-line change on `AddButton` at line 282–290: `.zoomSource(.createButton)` after the existing accessibility modifiers.
   - No new init parameters; no namespace threaded as a prop.

## Data flow

```
RootScene (@Namespace zoomNS)
    └── environment(\.zoomNamespace, zoomNS)
            └── RecordsListScene
                    └── AddButton.zoomSource(.createButton)
                        // reads env → matchedTransitionSource(id: "createButton", in: zoomNS)
            └── .sheet(isPresented:) { CreateRecordScene.zoomDestination(.createButton) }
                // reads env → navigationTransition(.zoom(sourceID: "createButton", in: zoomNS))
```

## Platform gating

- `.matchedTransitionSource` is iOS 18+. `.navigationTransition(.zoom(sourceID:in:))` is iOS 18+.
- Project deployment target is iOS 18 (confirmed in `Packages/Package.swift`). No version branch needed.
- macOS host-side tests use `DesignSystem`: gate the inner modifier applications with `#if os(iOS)` so the helpers compile on macOS but no-op.

## Testing

- **`DesignSystemTests/ZoomTransitionTests.swift`** (new)
  - `@MainActor` suite — SwiftUI modifiers touch actor-isolated state.
  - Test: view with `.zoomSource(.createButton)` builds without crashing when env namespace is `nil`.
  - Test: view with `.zoomSource(.createButton)` builds without crashing when env namespace is set.
  - Test: same for `.zoomDestination`.
  - We do not try to assert that `matchedTransitionSource` is actually applied — SwiftUI offers no public inspection, and the goal is catching wiring regressions, not animation correctness.
- **`AppFeatureTests`** — no changes required; existing `RootSceneTests` continue to pass through the new env-injection.
- **Manual verification** (iPhone 17 simulator via `ios-simulator` MCP):
  1. `xcodebuild build && install && launch_app`.
  2. `ui_tap` the `+` button.
  3. `screenshot` mid/post-transition.
  4. Expected: visibly zoom-morphs rather than bottom-sheet slide-up.

## Risks & mitigations

- **Namespace injected via environment might be shadowed**: only `RootScene` owns one; there's no second root. Low risk.
- **Sheet presentation timing**: the `matchedTransitionSource` view must be in the hierarchy at the moment of presentation. The `+` button is always present on `RecordsListScene`, which is behind the sheet. Expected to work; verify on simulator.
- **Design fidelity**: Figma does not specify this transition (it's a platform-native affordance). No Figma fetch required; no visual QA beyond confirming the zoom renders.

## Out of scope — follow-ups to consider later

- Zoom from a card row → medium detail sheet.
- Zoom from the edit entry point in the detail sheet → Create (editing mode).
- Any custom fallback when `UIAccessibility.isReduceMotionEnabled` is true (SwiftUI's default behavior is acceptable for v1).

## Rollout

Single feature branch → merge fast-forward to `main` once the plan's tasks complete and manual simulator check passes. No migration, no feature flag.
