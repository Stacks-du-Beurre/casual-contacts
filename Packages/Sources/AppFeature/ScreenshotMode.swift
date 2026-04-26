import Foundation
import SwiftUI

/// Launch-argument switches that put the app into a deterministic state for
/// App Store screenshot generation. The UI test target enables these via
/// `XCUIApplication.launchArguments`; production launches see none of them
/// and behave normally.
///
/// Usage from the test target (one example shot):
/// ```
/// app.launchArguments = [
///     "-ScreenshotMode", "YES",
///     "-ScreenshotSeed", "YES",
///     "-AppearanceOverride", "dark",
/// ]
/// ```
public enum ScreenshotMode {

    /// Master switch. When true, the app uses an in-memory store, a fixed
    /// "current location" (San Francisco), a frozen device tilt, and a
    /// fixed wall-clock time-of-day so each card paints the same gradient
    /// across runs.
    public static var isEnabled: Bool {
        flag("-ScreenshotMode")
    }

    /// When true (and `isEnabled` is also true), the in-memory store is
    /// pre-populated with `ScreenshotSeeder.records` shortly after launch.
    /// Off for the empty-state shot; on for the list/detail shots.
    public static var shouldSeed: Bool {
        flag("-ScreenshotSeed")
    }

    /// Forces the app's color scheme regardless of system settings. Returns
    /// nil if the launch arg is absent or unrecognized — the app then
    /// follows the system appearance.
    public static var appearanceOverride: ColorScheme? {
        switch value(for: "-AppearanceOverride")?.lowercased() {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    /// Seeds curated records into the live store if `shouldSeed` is on.
    /// Idempotent: re-running with the same fixtures is a no-op because
    /// `RecordStore.insert` upserts on the supplied UUID.
    @MainActor
    public static func seedIfNeeded(into environment: AppEnvironment) async {
        guard isEnabled, shouldSeed else { return }
        let store = environment.recordStore
        for record in ScreenshotSeeder.records {
            try? await store.insert(record)
        }
    }

    private static func flag(_ name: String) -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: name), i + 1 < args.count else {
            return false
        }
        return args[i + 1].uppercased() == "YES"
    }

    private static func value(for name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: name), i + 1 < args.count else {
            return nil
        }
        return args[i + 1]
    }
}
