# App Internationalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add app-only internationalization for English, Russian, and Ukrainian, including device-language support and an in-app language override.

**Architecture:** Use Apple-native localization through String Catalogs (`Localizable.xcstrings`) owned by the Swift package UI targets. Store the app language choice as a small shared enum, apply the selected locale at `RootScene`, and expose the picker from `SettingsSheet`.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager resources, Xcode String Catalogs, Swift Testing.

---

## File Structure

- Modify `Packages/Package.swift`
  - Add `defaultLocalization: "en"`.
  - Add `.process("Resources")` to package targets that own localized UI strings.
- Create `Packages/Sources/CoreModels/Types/AppLanguagePreference.swift`
  - Shared enum for `system`, `en`, `ru`, and `uk`.
  - Holds raw storage values, locale identifiers, and localized display resources.
- Create `Packages/Tests/CoreModelsTests/AppLanguagePreferenceTests.swift`
  - Unit tests for raw values, locale identifiers, and fallback parsing.
- Modify `Packages/Sources/AppFeature/RootScene.swift`
  - Store the language override in `@AppStorage`.
  - Apply `.environment(\.locale, Locale(identifier: ...))` when a non-system language is selected.
  - Pass the selected preference and setter into `SettingsSheet`.
- Modify `Packages/Sources/FeatureSettings/SettingsSheet.swift`
  - Add a Language section under General.
  - Add a `languagePreference` binding and render a picker.
- Modify `Packages/Sources/FeatureSettings/SettingsChrome.swift`
  - Change UI-copy labels from `String` to `LocalizedStringResource` where they are static app text.
- Modify `Packages/Tests/FeatureSettingsTests/SettingsTests.swift`
  - Add smoke tests for the new initializer and language selector.
- Create `Packages/Sources/FeatureSettings/Resources/Localizable.xcstrings`
  - Settings, language picker, developer rows, about rows, and settings footer strings.
- Create `Packages/Sources/FeatureList/Resources/Localizable.xcstrings`
  - List, empty-state, sorting, settings/create button accessibility strings.
- Create `Packages/Sources/FeatureCreate/Resources/Localizable.xcstrings`
  - Create flow, photo source, save/cancel, zodiac picker, metadata strips.
- Create `Packages/Sources/FeatureDetail/Resources/Localizable.xcstrings`
  - Detail, edit, delete, zodiac, and accessibility strings.
- Create `Packages/Sources/AppFeature/Resources/Localizable.xcstrings`
  - Root alerts, location primer host strings, delete/location error strings, debug-only host strings.
- Modify Swift files with hardcoded user-facing strings in these folders:
  - `Packages/Sources/FeatureList`
  - `Packages/Sources/FeatureCreate`
  - `Packages/Sources/FeatureDetail`
  - `Packages/Sources/FeatureSettings`
  - `Packages/Sources/AppFeature`

## Task 1: Add Shared Language Preference Model

**Files:**
- Create: `Packages/Sources/CoreModels/Types/AppLanguagePreference.swift`
- Create: `Packages/Tests/CoreModelsTests/AppLanguagePreferenceTests.swift`

- [ ] **Step 1: Write failing tests**

Add `Packages/Tests/CoreModelsTests/AppLanguagePreferenceTests.swift`:

```swift
import Testing
import SwiftUI
@testable import CoreModels

@Suite struct AppLanguagePreferenceTests {

    @Test func rawValuesAreStableForPersistence() {
        #expect(AppLanguagePreference.system.rawValue == "system")
        #expect(AppLanguagePreference.english.rawValue == "en")
        #expect(AppLanguagePreference.russian.rawValue == "ru")
        #expect(AppLanguagePreference.ukrainian.rawValue == "uk")
    }

    @Test func localeIdentifierIsNilForSystemDefault() {
        #expect(AppLanguagePreference.system.localeIdentifier == nil)
    }

    @Test func localeIdentifiersMatchAppleLanguageCodes() {
        #expect(AppLanguagePreference.english.localeIdentifier == "en")
        #expect(AppLanguagePreference.russian.localeIdentifier == "ru")
        #expect(AppLanguagePreference.ukrainian.localeIdentifier == "uk")
    }

    @Test func invalidStoredValueFallsBackToSystem() {
        #expect(AppLanguagePreference(storedValue: "de") == .system)
        #expect(AppLanguagePreference(storedValue: "") == .system)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd Packages
swift test --filter AppLanguagePreferenceTests
```

Expected: FAIL because `AppLanguagePreference` is not defined.

- [ ] **Step 3: Add minimal model**

Create `Packages/Sources/CoreModels/Types/AppLanguagePreference.swift`:

```swift
import SwiftUI

public enum AppLanguagePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case russian = "ru"
    case ukrainian = "uk"

    public var id: String { rawValue }

    public init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .system
    }

    public var localeIdentifier: String? {
        switch self {
        case .system:
            nil
        case .english:
            "en"
        case .russian:
            "ru"
        case .ukrainian:
            "uk"
        }
    }

    public var displayName: LocalizedStringResource {
        switch self {
        case .system:
            "language.system"
        case .english:
            "language.english"
        case .russian:
            "language.russian"
        case .ukrainian:
            "language.ukrainian"
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
cd Packages
swift test --filter AppLanguagePreferenceTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/CoreModels/Types/AppLanguagePreference.swift Packages/Tests/CoreModelsTests/AppLanguagePreferenceTests.swift
git commit -m "feat: add app language preference model"
```

## Task 2: Enable Localized Resources In Package Targets

**Files:**
- Modify: `Packages/Package.swift`
- Create: `Packages/Sources/AppFeature/Resources/Localizable.xcstrings`
- Create: `Packages/Sources/FeatureCreate/Resources/Localizable.xcstrings`
- Create: `Packages/Sources/FeatureDetail/Resources/Localizable.xcstrings`
- Create: `Packages/Sources/FeatureList/Resources/Localizable.xcstrings`
- Create: `Packages/Sources/FeatureSettings/Resources/Localizable.xcstrings`

- [ ] **Step 1: Modify package localization metadata**

In `Packages/Package.swift`, change the package declaration to include `defaultLocalization`:

```swift
let package = Package(
    name: "CasualContactsPackages",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v14)],
```

For each UI target currently declared without resources, add resource processing:

```swift
.target(
    name: "FeatureList",
    dependencies: ["CoreModels", "DesignSystem", "Visuals"],
    path: "Sources/FeatureList",
    resources: [.process("Resources")]
),
.target(
    name: "FeatureCreate",
    dependencies: ["CoreModels", "DesignSystem", "Visuals"],
    path: "Sources/FeatureCreate",
    resources: [.process("Resources")]
),
.target(
    name: "FeatureDetail",
    dependencies: ["CoreModels", "DesignSystem", "Visuals"],
    path: "Sources/FeatureDetail",
    resources: [.process("Resources")]
),
.target(
    name: "FeatureSettings",
    dependencies: ["CoreModels", "DesignSystem", "Visuals"],
    path: "Sources/FeatureSettings",
    resources: [.process("Resources")]
),
.target(
    name: "AppFeature",
    dependencies: [
        "CoreModels",
        "Storage",
        "Services",
        "DesignSystem",
        "Visuals",
        "FeatureList",
        "FeatureCreate",
        "FeatureDetail",
        "FeatureSettings"
    ],
    path: "Sources/AppFeature",
    resources: [.process("Resources")]
)
```

- [ ] **Step 2: Add starter string catalogs**

Create each `Localizable.xcstrings` with this structure, replacing the `strings` object with target-specific keys in later tasks:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
  },
  "version" : "1.0"
}
```

- [ ] **Step 3: Run package tests to verify resources compile**

Run:

```bash
cd Packages
swift test --filter SettingsTests/settingsSheetInstantiates
```

Expected: PASS. If SwiftPM reports a missing `Resources` directory, confirm all five resource directories exist before rerunning.

- [ ] **Step 4: Commit**

```bash
git add Packages/Package.swift Packages/Sources/AppFeature/Resources/Localizable.xcstrings Packages/Sources/FeatureCreate/Resources/Localizable.xcstrings Packages/Sources/FeatureDetail/Resources/Localizable.xcstrings Packages/Sources/FeatureList/Resources/Localizable.xcstrings Packages/Sources/FeatureSettings/Resources/Localizable.xcstrings
git commit -m "chore: enable package localization resources"
```

## Task 3: Add Root Locale Override

**Files:**
- Modify: `Packages/Sources/AppFeature/RootScene.swift`
- Modify: `Packages/Tests/AppFeatureTests/RootSceneTests.swift`

- [ ] **Step 1: Write failing model-level test for locale construction**

Append to `Packages/Tests/AppFeatureTests/RootSceneTests.swift`:

```swift
@Test func selectedLocaleUsesLanguagePreferenceIdentifier() {
    #expect(RootScene.locale(for: .system) == nil)
    #expect(RootScene.locale(for: .english)?.identifier == "en")
    #expect(RootScene.locale(for: .russian)?.identifier == "ru")
    #expect(RootScene.locale(for: .ukrainian)?.identifier == "uk")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd Packages
swift test --filter RootSceneTests/selectedLocaleUsesLanguagePreferenceIdentifier
```

Expected: FAIL because `RootScene.locale(for:)` is not defined.

- [ ] **Step 3: Add AppStorage-backed preference and locale helper**

In `Packages/Sources/AppFeature/RootScene.swift`, add the stored value near the existing `@State` properties:

```swift
@AppStorage("appLanguagePreference") private var appLanguagePreferenceRawValue = AppLanguagePreference.system.rawValue
```

Add this computed binding inside `RootScene`:

```swift
private var appLanguagePreference: Binding<AppLanguagePreference> {
    Binding(
        get: { AppLanguagePreference(storedValue: appLanguagePreferenceRawValue) },
        set: { appLanguagePreferenceRawValue = $0.rawValue }
    )
}
```

Add this public testable helper inside `RootScene`:

```swift
public static func locale(for preference: AppLanguagePreference) -> Locale? {
    guard let identifier = preference.localeIdentifier else { return nil }
    return Locale(identifier: identifier)
}
```

Wrap `rootContent` with locale application in `body`:

```swift
WindowGroup {
    #if os(iOS)
    localizedRootContent
        .environment(\.zoomNamespace, zoomNamespace)
        .preferredColorScheme(ScreenshotMode.appearanceOverride)
        .task {
            await ScreenshotMode.seedIfNeeded(into: environment)
        }
    #else
    Text("RootScene is iOS-only")
    #endif
}
```

Add this view helper:

```swift
@MainActor
@ViewBuilder
private var localizedRootContent: some View {
    if let locale = Self.locale(for: appLanguagePreference.wrappedValue) {
        rootContent.environment(\.locale, locale)
    } else {
        rootContent
    }
}
```

- [ ] **Step 4: Pass language binding into settings**

In the `SettingsSheet` initializer call in `RootScene`, add:

```swift
languagePreference: appLanguagePreference,
```

immediately after `onAbout: { router.showingAbout = true },`.

- [ ] **Step 5: Run test to verify it passes**

Run:

```bash
cd Packages
swift test --filter RootSceneTests/selectedLocaleUsesLanguagePreferenceIdentifier
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Packages/Sources/AppFeature/RootScene.swift Packages/Tests/AppFeatureTests/RootSceneTests.swift
git commit -m "feat: apply app language locale override"
```

## Task 4: Add Language Picker To Settings

**Files:**
- Modify: `Packages/Sources/FeatureSettings/SettingsSheet.swift`
- Modify: `Packages/Sources/FeatureSettings/SettingsChrome.swift`
- Modify: `Packages/Tests/FeatureSettingsTests/SettingsTests.swift`
- Modify: `Packages/Sources/FeatureSettings/Resources/Localizable.xcstrings`

- [ ] **Step 1: Write failing settings tests**

Append to `Packages/Tests/FeatureSettingsTests/SettingsTests.swift`:

```swift
@Test func settingsSheetAcceptsLanguagePreferenceBinding() {
    @State var preference = AppLanguagePreference.system
    _ = SettingsSheet(onAbout: {}, languagePreference: $preference).body
}

@Test func allLanguagePreferencesHaveDisplayNames() {
    for preference in AppLanguagePreference.allCases {
        #expect(String(localized: preference.displayName).isEmpty == false)
    }
}
```

Add `import CoreModels` at the top of the file.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd Packages
swift test --filter FeatureSettingsTests
```

Expected: FAIL because `SettingsSheet` does not accept `languagePreference`.

- [ ] **Step 3: Update settings row helpers to localized labels**

In `Packages/Sources/FeatureSettings/SettingsChrome.swift`, change label and title types:

```swift
struct SettingsRow<Trailing: View>: View {
    @Environment(\.colorScheme) private var scheme
    let label: LocalizedStringResource
    let onTap: (() -> Void)?
    @ViewBuilder let trailing: () -> Trailing
```

```swift
struct SettingsToggleRow: View {
    @Environment(\.colorScheme) private var scheme
    let label: LocalizedStringResource
    @Binding var isOn: Bool
```

```swift
struct SettingsGroup<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let title: LocalizedStringResource?
    @ViewBuilder let content: () -> Content

    init(title: LocalizedStringResource? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
```

The existing `Text(label)` calls remain valid.

- [ ] **Step 4: Add binding and picker to SettingsSheet**

In `Packages/Sources/FeatureSettings/SettingsSheet.swift`, add `import CoreModels` if it is not already present.

Add the binding property:

```swift
@Binding private var languagePreference: AppLanguagePreference
```

Update the initializer signature:

```swift
public init(
    onAbout: @escaping () -> Void,
    languagePreference: Binding<AppLanguagePreference> = .constant(.system),
    onAddDebugRecords: @escaping () -> Void = {},
```

Assign the binding in the initializer:

```swift
_languagePreference = languagePreference
```

Add `languagePickerRow` after the two existing General toggles:

```swift
SettingsDivider()
languagePickerRow
```

Add this view:

```swift
private var languagePickerRow: some View {
    HStack(spacing: 12) {
        Text("settings.language")
            .font(CCDesign.Typography.description)
            .tracking(CCDesign.Typography.Tracking.description)
            .foregroundStyle(SettingsPalette.label(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)

        Picker("settings.language", selection: $languagePreference) {
            ForEach(AppLanguagePreference.allCases) { preference in
                Text(preference.displayName).tag(preference)
            }
        }
        .labelsHidden()
    }
    .padding(.horizontal, 16)
    .frame(minHeight: 43)
}
```

- [ ] **Step 5: Add FeatureSettings translations**

Replace `Packages/Sources/FeatureSettings/Resources/Localizable.xcstrings` with:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "About" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "About" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "О приложении" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Про застосунок" } } } },
    "About developers" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "About developers" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "О разработчиках" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Про розробників" } } } },
    "Cancel" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Cancel" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Отмена" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Скасувати" } } } },
    "Casual Contacts" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Casual Contacts" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Casual Contacts" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Casual Contacts" } } } },
    "Casual Contacts Version %@" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Casual Contacts Version %@" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Casual Contacts, версия %@" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Casual Contacts, версія %@" } } } },
    "Contact" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Contact" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Контакты" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Контакти" } } } },
    "Developer" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Developer" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Разработчик" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Розробник" } } } },
    "Developer settings" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Developer settings" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Настройки разработчика" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Налаштування розробника" } } } },
    "General" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "General" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Основные" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Загальні" } } } },
    "In-list developer settings" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "In-list developer settings" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Настройки разработчика в списке" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Налаштування розробника у списку" } } } },
    "Location" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Location" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Геолокация" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Геолокація" } } } },
    "Motion debug" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Motion debug" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Отладка движения" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Налагодження руху" } } } },
    "Motion service unavailable" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Motion service unavailable" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Сервис движения недоступен" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Сервіс руху недоступний" } } } },
    "Rate on the App Store" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Rate on the App Store" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Оценить в App Store" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Оцінити в App Store" } } } },
    "Recommended Casual Contacts" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Recommended Casual Contacts" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Порекомендовать Casual Contacts" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Порекомендувати Casual Contacts" } } } },
    "Settings" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Settings" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Настройки" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Налаштування" } } } },
    "Support" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Support" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Поддержка" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Підтримка" } } } },
    "Sync data with iCloud" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Sync data with iCloud" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Синхронизировать данные с iCloud" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Синхронізувати дані з iCloud" } } } },
    "Turn on advanced card stack" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Turn on advanced card stack" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Включить расширенную стопку карточек" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Увімкнути розширену стопку карток" } } } },
    "Use my location" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Use my location" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Использовать мою геопозицию" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Використовувати моє місцезнаходження" } } } },
    "language.english" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "English" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Английский" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Англійська" } } } },
    "language.russian" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Russian" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Русский" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Російська" } } } },
    "language.system" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "System Default" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Как в системе" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Як у системі" } } } },
    "language.ukrainian" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Ukrainian" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Украинский" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Українська" } } } },
    "settings.language" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Language" } }, "ru" : { "stringUnit" : { "state" : "translated", "value" : "Язык" } }, "uk" : { "stringUnit" : { "state" : "translated", "value" : "Мова" } } } }
  },
  "version" : "1.0"
}
```

- [ ] **Step 6: Localize version string construction**

In `SettingsSheet.versionString`, replace:

```swift
return "Casual Contacts Version \(version)"
```

with:

```swift
return String(localized: "Casual Contacts Version \(version)")
```

- [ ] **Step 7: Run tests**

Run:

```bash
cd Packages
swift test --filter FeatureSettingsTests
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Packages/Sources/FeatureSettings Packages/Tests/FeatureSettingsTests/SettingsTests.swift
git commit -m "feat: add app language picker"
```

## Task 5: Localize Feature UI Strings

**Files:**
- Modify: Swift files under `Packages/Sources/FeatureList`
- Modify: Swift files under `Packages/Sources/FeatureCreate`
- Modify: Swift files under `Packages/Sources/FeatureDetail`
- Modify: Swift files under `Packages/Sources/AppFeature`
- Modify: corresponding `Localizable.xcstrings` files

- [ ] **Step 1: Generate the hardcoded UI string audit**

Run:

```bash
rg -n 'Text\(|Label\(|Button\(|TextField\(|navigationTitle|accessibilityLabel|accessibilityHint|alert\(|confirmationDialog|Section\(' Packages/Sources/FeatureList Packages/Sources/FeatureCreate Packages/Sources/FeatureDetail Packages/Sources/AppFeature --glob '*.swift'
```

Expected: A list of user-facing literals to either keep as user data or localize.

- [ ] **Step 2: Convert SwiftUI literals that are already localizable**

Keep these forms when the text is static app copy:

```swift
Text("Settings")
Button("Save") { save() }
.navigationTitle("Edit")
TextField("Name", text: $name)
```

Do not convert user-generated content:

```swift
Text(record.name)
Text(record.description)
Text(location.label)
```

- [ ] **Step 3: Convert dynamic strings to String(localized:)**

Replace dynamic user-facing strings with localized interpolation.

Example in `RootScene.deletePresentedRecord`:

```swift
let name = record.name.isEmpty ? String(localized: "this contact") : record.name
deleteErrorMessage = String(localized: "Couldn't delete \(name). Try again.")
```

Example for location debug errors:

```swift
nearbyDebugError = String(localized: "Enable location access for Casual Contacts in iOS Settings to seed nearby records.")
nearbyDebugError = String(localized: "Couldn't determine your current location. Try again with a clearer GPS signal.")
```

- [ ] **Step 4: Add AppFeature catalog entries**

Add these keys to `Packages/Sources/AppFeature/Resources/Localizable.xcstrings` with English, Russian, and Ukrainian translations:

```text
"Location Required"
"OK"
"Couldn't delete contact"
"Couldn't delete %@. Try again."
"this contact"
"Enable location access for Casual Contacts in iOS Settings to seed nearby records."
"Couldn't determine your current location. Try again with a clearer GPS signal."
"Done"
"RootScene is iOS-only"
```

- [ ] **Step 5: Add FeatureList catalog entries**

Add entries for every static UI string found in `Packages/Sources/FeatureList`, including at minimum:

```text
"add the first person"
"Opens the new contact form"
"Sort"
"Alphabetical"
"Distance"
"Recent"
"Settings"
```

- [ ] **Step 6: Add FeatureCreate catalog entries**

Add entries for every static UI string found in `Packages/Sources/FeatureCreate`, including at minimum:

```text
"Name"
"Description"
"Save"
"Cancel"
"Photo"
"Camera"
"Photo Library"
"Zodiac"
"None"
"Add"
"Use Photo"
"Retake"
```

- [ ] **Step 7: Add FeatureDetail catalog entries**

Add entries for every static UI string found in `Packages/Sources/FeatureDetail`, including at minimum:

```text
"Expand"
"Edit"
"Delete"
"EDIT"
"DELETE"
"Dismiss"
"Name"
"Description"
"Zodiac:"
"Location: %@"
"Save"
"Cancel"
"None"
"Sign"
"Zodiac"
```

- [ ] **Step 8: Run package tests**

Run:

```bash
cd Packages
swift test
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add Packages/Sources/FeatureList Packages/Sources/FeatureCreate Packages/Sources/FeatureDetail Packages/Sources/AppFeature
git commit -m "feat: localize app feature strings"
```

## Task 6: Verify Cyrillic Font Coverage And Fallbacks

**Files:**
- Modify: `Packages/Tests/DesignSystemTests/TypographyTests.swift`
- Modify only if needed: `Packages/Sources/DesignSystem/Typography.swift`

- [ ] **Step 1: Add font coverage tests**

Append to `Packages/Tests/DesignSystemTests/TypographyTests.swift`:

```swift
import CoreText

@Test func bundledFontsCoverRussianAndUkrainianSampleText() throws {
    let samples = [
        "Настройки Сохранить Удалить",
        "Налаштування Зберегти Видалити ї є ґ і"
    ]
    let fontNames = [
        "CormorantSC-Bold",
        "CormorantSC-SemiBold",
        "CormorantInfant-SemiBold",
        "IBMPlexMono-Regular"
    ]

    for fontName in fontNames {
        let font = CTFontCreateWithName(fontName as CFString, 16, nil)
        for sample in samples {
            let characters = Array(sample)
            let scalars = characters.map { UniChar(String($0).utf16.first!) }
            var glyphs = Array(repeating: CGGlyph(), count: scalars.count)
            let hasGlyphs = CTFontGetGlyphsForCharacters(font, scalars, &glyphs, scalars.count)
            #expect(hasGlyphs, "\(fontName) is missing glyphs for \(sample)")
        }
    }
}
```

- [ ] **Step 2: Run font coverage test**

Run:

```bash
cd Packages
swift test --filter bundledFontsCoverRussianAndUkrainianSampleText
```

Expected: PASS if bundled fonts cover required Cyrillic. If this fails, proceed to Step 3.

- [ ] **Step 3: Add locale-aware fallback only if coverage fails**

If a custom font lacks required glyphs, modify `Packages/Sources/DesignSystem/Typography.swift` to provide a fallback token for long-form UI copy:

```swift
public static func localizedDescription(locale: Locale) -> Font {
    if locale.language.languageCode?.identifier == "ru" || locale.language.languageCode?.identifier == "uk" {
        return .system(.body, design: .serif, weight: .semibold)
    }
    return description
}
```

Then use that token only in views where the failing font rendered localized Russian/Ukrainian copy.

- [ ] **Step 4: Run design system tests**

Run:

```bash
cd Packages
swift test --filter DesignSystemTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/Sources/DesignSystem/Typography.swift Packages/Tests/DesignSystemTests/TypographyTests.swift
git commit -m "test: verify cyrillic font coverage"
```

## Task 7: Add Localization Completeness Guard

**Files:**
- Create: `Packages/Tests/AppFeatureTests/LocalizationCatalogTests.swift`

- [ ] **Step 1: Add catalog validation tests**

Create `Packages/Tests/AppFeatureTests/LocalizationCatalogTests.swift`:

```swift
import Foundation
import Testing

@Suite struct LocalizationCatalogTests {

    @Test func stringCatalogsContainEnglishRussianAndUkrainianForEveryKey() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let catalogPaths = [
            "Sources/AppFeature/Resources/Localizable.xcstrings",
            "Sources/FeatureCreate/Resources/Localizable.xcstrings",
            "Sources/FeatureDetail/Resources/Localizable.xcstrings",
            "Sources/FeatureList/Resources/Localizable.xcstrings",
            "Sources/FeatureSettings/Resources/Localizable.xcstrings"
        ]

        for path in catalogPaths {
            let url = packageRoot.appendingPathComponent(path)
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(StringCatalog.self, from: data)

            for key in catalog.strings.keys {
                let localizations = catalog.strings[key]?.localizations ?? [:]
                #expect(localizations["en"]?.stringUnit.value.isEmpty == false, "\(path) missing en for \(key)")
                #expect(localizations["ru"]?.stringUnit.value.isEmpty == false, "\(path) missing ru for \(key)")
                #expect(localizations["uk"]?.stringUnit.value.isEmpty == false, "\(path) missing uk for \(key)")
            }
        }
    }
}

private struct StringCatalog: Decodable {
    let strings: [String: Entry]

    struct Entry: Decodable {
        let localizations: [String: Localization]?
    }

    struct Localization: Decodable {
        let stringUnit: StringUnit
    }

    struct StringUnit: Decodable {
        let value: String
    }
}
```

- [ ] **Step 2: Run validation test**

Run:

```bash
cd Packages
swift test --filter LocalizationCatalogTests
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add Packages/Tests/AppFeatureTests/LocalizationCatalogTests.swift
git commit -m "test: require complete localization catalogs"
```

## Task 8: Simulator Verification

**Files:**
- No required source edits.
- Update source only if simulator verification reveals clipping or untranslated UI.

- [ ] **Step 1: Run all host tests**

Run:

```bash
cd Packages
swift test
```

Expected: PASS.

- [ ] **Step 2: Build the iOS app**

Run:

```bash
xcodebuild build \
  -scheme CasualContacts \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Manual simulator smoke test**

Run the app in Simulator and verify:

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install "iPhone 17" CasualContacts/build/Debug-iphonesimulator/CasualContacts.app
xcrun simctl launch "iPhone 17" com.stacksdubeurre.CasualContacts
```

Expected manual results:

- Settings shows Language with System Default, English, Russian, Ukrainian.
- Selecting Russian updates visible static app copy to Russian without relaunch.
- Selecting Ukrainian updates visible static app copy to Ukrainian without relaunch.
- Selecting System Default returns to the simulator/device language behavior.
- Contact names, descriptions, and location labels remain user-entered data and are not translated.
- Cyrillic names entered into create/edit fields save and render on cards.
- No obvious clipping in settings rows, edit form, create form, alerts, or empty state.

- [ ] **Step 4: Final hardcoded string audit**

Run:

```bash
rg -n '"[A-Za-z][^"]*"' Packages/Sources/FeatureList Packages/Sources/FeatureCreate Packages/Sources/FeatureDetail Packages/Sources/FeatureSettings Packages/Sources/AppFeature --glob '*.swift'
```

Expected: remaining English literals are either localization keys, system image names, accessibility identifiers, debug-only seed data, bundle keys, comments, or user-data fixtures. Localize any remaining production UI copy before completing.

- [ ] **Step 5: Commit final fixes**

```bash
git add Packages
git commit -m "chore: verify app internationalization"
```

## Self-Review

- Spec coverage: The plan covers system-language behavior, in-app override, app-only scope, translation files, Cyrillic display, and tests.
- Placeholder scan: The plan has no incomplete placeholder markers. The catalog audit tasks intentionally require adding all strings found by the command because the exact list depends on the current code at implementation time.
- Type consistency: `AppLanguagePreference` is defined in `CoreModels`; both `FeatureSettings` and `AppFeature` already depend on `CoreModels`, so no dependency cycle is introduced.
