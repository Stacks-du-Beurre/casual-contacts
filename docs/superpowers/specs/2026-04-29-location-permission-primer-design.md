# Location Permission Primer - Design

**Status:** approved 2026-04-29
**Scope:** Add an app-styled explanatory modal before requesting location permission.

## 1. Goals & Non-Goals

### Goals

- Show a branded, app-styled primer before the app asks iOS for location permission.
- Explain that location powers location-based card sorting, helping nearby names surface when the user opens the app.
- Show the primer the first time a user creates a card while location authorization is still undecided.
- Respect a user declining the primer during create: do not ask iOS for permission and do not show the primer again during create.
- Let Settings remain the explicit recovery path. If the user taps the location toggle later, show the primer as the explanation before either asking iOS for permission or redirecting to iOS Settings.

### Non-Goals

- No change to how card locations are captured once permission is authorized.
- No continuous background location tracking.
- No custom replacement for the iOS permission alert.
- No migration of existing records or stored location values.

## 2. User-Facing Copy

Primer title:

```text
USE LOCATION?
```

Primer body:

```text
Location helps Casual Contacts sort cards by where you met people, so nearby names can surface when you open the app.
```

Primary action:

```text
Use Location
```

Secondary action:

```text
Not Now
```

## 3. UI Design

Create a reusable SwiftUI component, `LocationPermissionPrimer`, in the app's feature layer. It should look like part of the existing settings/create surface rather than a system alert.

Visual rules:

- Use `CCDesign.Colors` and existing light/dark palette behavior.
- Use `CCDesign.Typography.headline` for the uppercase title with existing headline tracking.
- Use `CCDesign.Typography.description` for the body text.
- Use an 8-12 pt corner radius, matching the app's current sheet/modal radius language.
- Use compact, clearly separated actions: a primary filled action and a quieter secondary action.
- Respect Dynamic Type through existing typography tokens.
- Do not introduce decorative imagery or a new color palette.

The component API should be simple:

```swift
LocationPermissionPrimer(
    onAccept: @escaping () -> Void,
    onDecline: @escaping () -> Void
)
```

The host decides whether accepting means calling the iOS permission prompt or opening iOS Settings.

## 4. State Model

Persist a tiny local primer decision in `UserDefaults`, behind a small protocol so tests can use an in-memory implementation.

```swift
enum LocationPermissionPrimerDecision {
    case notAnswered
    case accepted
    case declined
}
```

Rules:

- Default is `.notAnswered`.
- Tapping `Not Now` stores `.declined`.
- Tapping `Use Location` stores `.accepted`.
- This value tracks the app primer only. It does not replace OS authorization state.

## 5. Create Flow

When the user taps the create button:

1. If OS authorization is `.authorized`, open create normally. The existing create-sheet location fetch remains unchanged.
2. If OS authorization is `.notDetermined` and primer decision is `.notAnswered`, show `LocationPermissionPrimer` before opening create.
3. If the user taps `Not Now`, persist `.declined`, dismiss the primer, and open create without requesting location.
4. If the user taps `Use Location`, persist `.accepted`, call `locationService.requestAuthorization()`, then open create.
5. If OS authorization is `.notDetermined` but primer decision is already `.declined`, open create without showing the primer and without requesting location.

This preserves card creation as the primary action. Declining location should not block creating a card.

## 6. Settings Toggle Flow

The Settings location toggle is the explicit place where a user can revisit location.

When the user taps the location toggle:

- If OS authorization is `.authorized`, keep the existing behavior: the toggle stays on.
- If OS authorization is `.notDetermined`, show the primer unless the host already has enough context to proceed.
  - `Not Now`: store `.declined`, leave the toggle off.
  - `Use Location`: store `.accepted`, call `requestAuthorization()`, then refresh the displayed authorization state.
- If OS authorization is `.denied`, show the primer as an explanation before redirecting.
  - `Not Now`: leave the toggle off.
  - `Use Location`: open the iOS Settings app because iOS cannot show the permission prompt again after denial.

This means a user who declined the create-time primer will not see it again during create, but can still see the explanation from Settings before making a new location decision.

## 7. Architecture

### AppFeature

- Add a small persisted preference object to `AppEnvironment`, such as `locationPermissionPrimerStore`.
- Production uses `UserDefaults`.
- Tests use an in-memory store.

### AppFeature Primer UI

- Add `LocationPermissionPrimer` as a reusable SwiftUI component in `AppFeature`.
- Keep the primer's presentation orchestration in `RootScene`, because `AppFeature` already owns app-level sheets, routing, environment services, and iOS Settings redirection.
- `FeatureSettings` should not import `AppFeature`; instead, `SettingsSheet` exposes a host callback for location-toggle intent and lets `RootScene` decide whether to show the primer, request authorization, or open iOS Settings.

### RootScene

- Change create-button handling from directly setting `router.showingCreate = true` to a small gate:
  - decide whether to show the primer,
  - request authorization only after user accepts,
  - then present create.
- Keep the existing create sheet's `locationProvider` behavior for authorized users.

### FeatureSettings

- Replace the current direct `requestLocationAuthorization` / `openSystemSettings` toggle handling with a host callback such as `onLocationToggleTapped`.
- Keep `readLocationAuthorization` so the sheet can display the current toggle state.
- After the host completes the primer/request/settings action, the sheet refreshes displayed authorization state through its existing local state.

## 8. Testing Strategy

Use test-first implementation.

Unit tests:

- Primer decision store defaults to `.notAnswered`.
- Primer decision store persists `.accepted` and `.declined`.
- Create gate shows primer for `.notDetermined + .notAnswered`.
- Create gate skips primer for `.notDetermined + .declined`.
- Accepting primer from create requests authorization and then opens create.
- Declining primer from create opens create without requesting authorization.
- Settings `.notDetermined` flow accepts by requesting authorization and refreshing state.
- Settings `.denied` flow accepts by opening iOS Settings, not by requesting authorization.

UI/component tests:

- `LocationPermissionPrimer` instantiates in light and dark color schemes.
- Primary and secondary button labels are present and wired to callbacks.

Existing tests:

- Existing create-flow tests should still pass.
- Existing settings tests should still pass after updating constructor dependencies.

## 9. Risks & Mitigations

- **Prompt timing feels intrusive.** Mitigation: only gate the first create attempt when OS auth is undecided; declining immediately continues to create.
- **State confusion between primer and OS auth.** Mitigation: keep primer decision and `LocationAuthorization` separate in code and tests.
- **Settings flow duplicates create logic.** Mitigation: extract a small gate/helper for the state machine, leaving views to render UI and call actions.
- **Dependency cycle between feature modules.** Mitigation: keep primer UI and orchestration in `AppFeature`; `FeatureSettings` reports toggle intent through callbacks.
