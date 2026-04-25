import SwiftUI
import CoreModels
import DesignSystem

public struct SettingsSheet: View {

    @Environment(\.colorScheme) private var scheme
    @State private var syncEnabled = false
    @State private var advancedCardStackEnabled = false
    @State private var path: [Route] = []
    @State private var locationAuthorization: LocationAuthorization = .notDetermined
    #if os(iOS)
    @State private var detent: PresentationDetent = .medium
    #endif
    public let onAbout: () -> Void
    public let onAddDebugRecords: () -> Void
    public let onAddNearbyDebugRecords: () -> Void
    public let onRemoveDebugRecords: () -> Void
    /// Reads current OS location authorization without prompting. Called on
    /// appear and after a permission request to refresh the toggle's
    /// displayed state.
    public let readLocationAuthorization: () -> LocationAuthorization
    /// Actually triggers the OS prompt (only meaningful when current state
    /// is `.notDetermined`). Returns the resolved status afterwards.
    public let requestLocationAuthorization: () async -> LocationAuthorization
    /// Opens the iOS Settings app deep-linked to this app's permissions
    /// page. Called when current state is `.denied` and the user wants to
    /// re-enable, since iOS doesn't allow re-prompting.
    public let openSystemSettings: () -> Void

    private enum Route: Hashable { case developer }

    public init(
        onAbout: @escaping () -> Void,
        onAddDebugRecords: @escaping () -> Void = {},
        onAddNearbyDebugRecords: @escaping () -> Void = {},
        onRemoveDebugRecords: @escaping () -> Void = {},
        readLocationAuthorization: @escaping () -> LocationAuthorization = { .notDetermined },
        requestLocationAuthorization: @escaping () async -> LocationAuthorization = { .notDetermined },
        openSystemSettings: @escaping () -> Void = {}
    ) {
        self.onAbout = onAbout
        self.onAddDebugRecords = onAddDebugRecords
        self.onAddNearbyDebugRecords = onAddNearbyDebugRecords
        self.onRemoveDebugRecords = onRemoveDebugRecords
        self.readLocationAuthorization = readLocationAuthorization
        self.requestLocationAuthorization = requestLocationAuthorization
        self.openSystemSettings = openSystemSettings
    }

    public var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .developer:
                        DeveloperSettingsPanel(
                            onAddDebugRecords: onAddDebugRecords,
                            onAddNearbyDebugRecords: onAddNearbyDebugRecords,
                            onRemoveDebugRecords: onRemoveDebugRecords
                        )
                    }
                }
        }
        .onAppear { locationAuthorization = readLocationAuthorization() }
        #if os(iOS)
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.hidden)
        .presentationBackground(SettingsPalette.sheetBackground(scheme))
        .onChange(of: path) { _, newPath in
            detent = newPath.contains(.developer) ? .large : .medium
        }
        #endif
    }

    private var root: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                groups
                    .padding(.top, 8)
                    .padding(.bottom, 16)
            }
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SettingsPalette.sheetBackground(scheme))
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private var header: some View {
        Text("Settings")
            .font(CCDesign.Typography.headline)
            .tracking(CCDesign.Typography.Tracking.headline)
            .textCase(.uppercase)
            .foregroundStyle(SettingsPalette.label(scheme))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .accessibilityAddTraits(.isHeader)
    }

    private var groups: some View {
        VStack(spacing: 24) {
            SettingsGroup(title: "General") {
                SettingsToggleRow(label: "Sync data with iCloud", isOn: $syncEnabled)
                SettingsDivider()
                SettingsToggleRow(label: "Turn on advanced card stack", isOn: $advancedCardStackEnabled)
            }

            SettingsGroup(title: "Location") {
                locationToggleRow
            }

            SettingsGroup(title: "Support") {
                SettingsRow(label: "Rate on the App Store", onTap: {}) {
                    trailingIcon(systemName: "star")
                }
                SettingsDivider()
                SettingsRow(label: "Recommended Casual Contacts", onTap: {}) {
                    trailingIcon(systemName: "square.and.arrow.up")
                }
            }

            SettingsGroup(title: "Developer") {
                SettingsRow(label: "Developer settings", onTap: { path.append(.developer) }) {
                    trailingIcon(systemName: "chevron.right", size: 14, weight: .semibold)
                }
            }

            SettingsGroup(title: "About") {
                SettingsRow(label: "About developers", onTap: onAbout) {
                    trailingIcon(systemName: "chevron.right", size: 14, weight: .semibold)
                }
            }
        }
    }

    /// Reflects the current OS location authorization. The toggle's getter
    /// returns `true` only when authorized; the setter NEVER flips the
    /// underlying authorization state directly (iOS doesn't expose that to
    /// apps) — instead it routes to the right action based on what the OS
    /// will actually let us do:
    /// - `.notDetermined` → call `requestAuthorization()` which surfaces
    ///   the system permission prompt.
    /// - `.denied`        → open the iOS Settings app deep-linked to this
    ///   app's permissions page; iOS won't re-prompt once denied.
    /// - `.authorized`    → already on; do nothing.
    /// After any action we re-read state via `readLocationAuthorization()`
    /// so the toggle's displayed position matches reality.
    private var locationToggleRow: some View {
        SettingsToggleRow(
            label: "Use my location",
            isOn: Binding(
                get: { locationAuthorization == .authorized },
                set: { _ in handleLocationToggleTapped() }
            )
        )
    }

    private func handleLocationToggleTapped() {
        switch locationAuthorization {
        case .notDetermined:
            Task {
                let resolved = await requestLocationAuthorization()
                await MainActor.run { locationAuthorization = resolved }
            }
        case .denied:
            openSystemSettings()
        case .authorized:
            // Already on. The toggle UI flickers off on user tap; refresh
            // reads the OS state back as `.authorized` and the toggle
            // returns to the on position on the next render.
            locationAuthorization = readLocationAuthorization()
        }
    }

    private func trailingIcon(systemName: String, size: CGFloat = 18, weight: Font.Weight = .regular) -> some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: weight))
            .frame(width: 44, height: 43)
            .accessibilityHidden(true)
    }

    private var footer: some View {
        Text(versionString)
            .font(CCDesign.Typography.caption2)
            .foregroundStyle(SettingsPalette.footer(scheme))
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Casual Contacts Version \(version)"
    }
}
