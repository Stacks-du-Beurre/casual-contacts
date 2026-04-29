# Location Permission Primer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add an app-styled pre-permission location primer that gates first card creation and Settings location-toggle recovery.

**Architecture:** Keep the primer UI, preference persistence, and permission flow orchestration in `AppFeature`, where app-level sheets and iOS Settings redirection already live. Keep `FeatureSettings` independent by replacing direct location actions with a host callback. Tests cover the preference store and pure permission-flow decisions before UI wiring.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, UserDefaults, existing `CoreModels.LocationAuthorization` and `LocationService`.

---

### Task 1: Primer Preference And Flow Decisions

**Files:**
- Create: `Packages/Sources/AppFeature/LocationPermissionPrimerStore.swift`
- Create: `Packages/Sources/AppFeature/LocationPermissionFlow.swift`
- Test: `Packages/Tests/AppFeatureTests/LocationPermissionPrimerTests.swift`

- [x] **Step 1: Write failing tests**

```swift
import Testing
import CoreModels
@testable import AppFeature

@Suite struct LocationPermissionPrimerTests {
    @Test func inMemoryStoreDefaultsToNotAnswered() {
        let store = InMemoryLocationPermissionPrimerStore()
        #expect(store.decision == .notAnswered)
    }

    @Test func inMemoryStorePersistsAcceptedAndDeclined() {
        let store = InMemoryLocationPermissionPrimerStore()
        store.decision = .accepted
        #expect(store.decision == .accepted)
        store.decision = .declined
        #expect(store.decision == .declined)
    }

    @Test func createGateShowsPrimerOnlyForUndecidedAuthAndUnansweredPrimer() {
        #expect(LocationPermissionFlow.createAction(
            authorization: .notDetermined,
            decision: .notAnswered
        ) == .showPrimer)
        #expect(LocationPermissionFlow.createAction(
            authorization: .notDetermined,
            decision: .declined
        ) == .openCreateWithoutLocationRequest)
        #expect(LocationPermissionFlow.createAction(
            authorization: .authorized,
            decision: .notAnswered
        ) == .openCreate)
    }

    @Test func settingsDeniedAcceptRedirectsInsteadOfRequestingAgain() {
        #expect(LocationPermissionFlow.settingsAcceptAction(authorization: .denied) == .openSystemSettings)
        #expect(LocationPermissionFlow.settingsAcceptAction(authorization: .notDetermined) == .requestAuthorization)
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages --filter LocationPermissionPrimerTests`

Expected: compile failure because `LocationPermissionFlow`, `InMemoryLocationPermissionPrimerStore`, and related types do not exist.

- [x] **Step 3: Implement minimal store and flow types**

Add `LocationPermissionPrimerDecision`, `LocationPermissionPrimerStore`, `UserDefaultsLocationPermissionPrimerStore`, and `InMemoryLocationPermissionPrimerStore`. Add `LocationPermissionFlow` with create/settings action enums and pure decision functions.

- [x] **Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages --filter LocationPermissionPrimerTests`

Expected: all tests in `LocationPermissionPrimerTests` pass.

### Task 2: Primer View

**Files:**
- Create: `Packages/Sources/AppFeature/LocationPermissionPrimer.swift`
- Test: `Packages/Tests/AppFeatureTests/LocationPermissionPrimerViewTests.swift`

- [x] **Step 1: Write failing view smoke tests**

```swift
import Testing
import SwiftUI
@testable import AppFeature

@MainActor
@Suite struct LocationPermissionPrimerViewTests {
    @Test func primerViewInstantiates() {
        _ = LocationPermissionPrimer(onAccept: {}, onDecline: {}).body
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages --filter LocationPermissionPrimerViewTests`

Expected: compile failure because `LocationPermissionPrimer` does not exist.

- [x] **Step 3: Implement minimal SwiftUI component**

Build a compact modal-style SwiftUI view using `CCDesign.Colors`, `CCDesign.Typography`, light/dark color scheme handling, a primary `Use Location` button, and a secondary `Not Now` button.

- [x] **Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages --filter LocationPermissionPrimerViewTests`

Expected: the view instantiation test passes.

### Task 3: Environment Wiring

**Files:**
- Modify: `Packages/Sources/AppFeature/AppEnvironment.swift`
- Modify: `Packages/Tests/AppFeatureTests/AppEnvironmentTesting.swift`
- Test: `Packages/Tests/AppFeatureTests/AppEnvironmentTests.swift`

- [x] **Step 1: Write failing environment test**

Add an assertion that `AppEnvironment.testing().locationPermissionPrimerStore.decision == .notAnswered`.

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages --filter AppEnvironmentTests`

Expected: compile failure because `AppEnvironment` has no `locationPermissionPrimerStore`.

- [x] **Step 3: Add environment dependency**

Add `public let locationPermissionPrimerStore: any LocationPermissionPrimerStore` to `AppEnvironment`, wire production/UI test/screenshot environments to `UserDefaultsLocationPermissionPrimerStore`, and wire tests to `InMemoryLocationPermissionPrimerStore`.

- [x] **Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages --filter AppEnvironmentTests`

Expected: environment tests pass.

### Task 4: Settings Toggle Host Callback

**Files:**
- Modify: `Packages/Sources/FeatureSettings/SettingsSheet.swift`
- Test: `Packages/Tests/FeatureSettingsTests/SettingsTests.swift`

- [x] **Step 1: Write failing callback test**

Add a smoke test constructing `SettingsSheet(onAbout: {}, onLocationToggleTapped: {})` so the new host callback API is required.

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages --filter SettingsTests`

Expected: compile failure until `SettingsSheet` accepts `onLocationToggleTapped`.

- [x] **Step 3: Add callback API**

Replace direct settings-toggle permission branching with a host callback. Keep `readLocationAuthorization` and local `locationAuthorization`; refresh it after invoking the callback.

- [x] **Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages --filter SettingsTests`

Expected: settings tests pass.

### Task 5: RootScene Orchestration

**Files:**
- Modify: `Packages/Sources/AppFeature/NavigationRouter.swift`
- Modify: `Packages/Sources/AppFeature/RootScene.swift`
- Test: `Packages/Tests/AppFeatureTests/RootSceneTests.swift`

- [x] **Step 1: Write failing router state test**

Add assertions for new primer presentation state on `NavigationRouter`, such as `pendingLocationPrimerContext == nil`.

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages --filter RootSceneTests`

Expected: compile failure until router primer state exists.

- [x] **Step 3: Implement RootScene gate**

Add a primer context enum for create/settings. On create tap, use `LocationPermissionFlow.createAction`. Present the primer in a sheet when needed. On primer accept/decline, persist the decision, request authorization or open iOS Settings as required, and continue create only for create context.

- [x] **Step 4: Run focused tests**

Run:
- `swift test --package-path Packages --filter LocationPermissionPrimerTests`
- `swift test --package-path Packages --filter SettingsTests`
- `swift test --package-path Packages --filter RootSceneTests`

Expected: all focused tests pass.

### Task 6: Full Verification

**Files:**
- No new files.

- [x] **Step 1: Run package test suite**

Run: `swift test --package-path Packages`

Expected: package tests pass. If unrelated pre-existing warnings appear, record them in the final response.

- [x] **Step 2: Review diff**

Run: `/usr/bin/git diff --stat` and `/usr/bin/git diff`

Expected: diff is scoped to the primer feature, settings callback, environment wiring, tests, and this plan.
