import SwiftUI
import CoreModels
import DesignSystem

public struct SettingsSheet: View {

    @Environment(\.colorScheme) private var scheme
    @State private var syncEnabled = false
    @State private var advancedCardStackEnabled = false
    @State private var path: [Route] = []
    @State private var locationAuthorization: LocationAuthorization = .notDetermined
    @Binding private var languagePreference: AppLanguagePreference
    #if os(iOS)
    @State private var detent: PresentationDetent = .medium
    #endif
    public let onAbout: () -> Void
    public let onAddDebugRecords: () -> Void
    public let onAddNearbyDebugRecords: () -> Void
    public let onRemoveDebugRecords: () -> Void
    public let onOpenLetterGallery: () -> Void
    public let onShowInListDeveloperSettings: () -> Void
    /// Reads current OS location authorization without prompting. Called on
    /// appear and after a permission request to refresh the toggle's
    /// displayed state.
    public let readLocationAuthorization: () -> LocationAuthorization
    /// Delegates location-toggle intent to the host, which owns the app-level
    /// primer, OS permission request, and iOS Settings redirect.
    public let onLocationToggleTapped: () async -> Void
    /// Optional MotionService injected by the host so the #if DEBUG motion
    /// debug screen can subscribe to `debugSamples`. nil hides the row.
    public let motionService: (any MotionService)?

    private enum Route: Hashable { case developer, motionDebug }

    public init(
        onAbout: @escaping () -> Void,
        languagePreference: Binding<AppLanguagePreference> = .constant(.system),
        onAddDebugRecords: @escaping () -> Void = {},
        onAddNearbyDebugRecords: @escaping () -> Void = {},
        onRemoveDebugRecords: @escaping () -> Void = {},
        onOpenLetterGallery: @escaping () -> Void = {},
        onShowInListDeveloperSettings: @escaping () -> Void = {},
        readLocationAuthorization: @escaping () -> LocationAuthorization = { .notDetermined },
        onLocationToggleTapped: @escaping () async -> Void = {},
        motionService: (any MotionService)? = nil
    ) {
        self.onAbout = onAbout
        _languagePreference = languagePreference
        self.onAddDebugRecords = onAddDebugRecords
        self.onAddNearbyDebugRecords = onAddNearbyDebugRecords
        self.onRemoveDebugRecords = onRemoveDebugRecords
        self.onOpenLetterGallery = onOpenLetterGallery
        self.onShowInListDeveloperSettings = onShowInListDeveloperSettings
        self.readLocationAuthorization = readLocationAuthorization
        self.onLocationToggleTapped = onLocationToggleTapped
        self.motionService = motionService
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
                            onRemoveDebugRecords: onRemoveDebugRecords,
                            onOpenLetterGallery: onOpenLetterGallery
                        )
                    case .motionDebug:
                        if let motionService {
                            MotionDebugScene(service: motionService)
                        } else {
                            Text("Motion service unavailable")
                        }
                    }
                }
        }
        .onAppear { locationAuthorization = readLocationAuthorization() }
        #if os(iOS)
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.hidden)
        .presentationBackground(SettingsPalette.sheetBackground(scheme))
        .onChange(of: path) { _, newPath in
            detent = newPath.contains(.developer) || newPath.contains(.motionDebug) ? .large : .medium
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
                SettingsDivider()
                SettingsRow(label: "In-list developer settings", onTap: onShowInListDeveloperSettings) {
                    trailingIcon(systemName: "rectangle.bottomthird.inset.filled")
                }
                #if DEBUG
                SettingsDivider()
                SettingsRow(label: "Motion debug", onTap: { path.append(.motionDebug) }) {
                    trailingIcon(systemName: "chevron.right", size: 14, weight: .semibold)
                }
                #endif
            }

            SettingsGroup(title: "About") {
                SettingsRow(label: "About developers", onTap: onAbout) {
                    trailingIcon(systemName: "chevron.right", size: 14, weight: .semibold)
                }
            }
        }
    }

    /// Reflects the current OS location authorization. The toggle's setter
    /// delegates all permission side effects to the host because only the host
    /// can present the app-level primer and open iOS Settings.
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
        Task {
            await onLocationToggleTapped()
            await MainActor.run {
                locationAuthorization = readLocationAuthorization()
            }
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
