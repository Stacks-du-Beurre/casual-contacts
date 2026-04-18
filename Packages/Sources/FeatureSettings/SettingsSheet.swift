import SwiftUI
import DesignSystem

public struct SettingsSheet: View {

    @State private var syncEnabled = false
    @State private var advancedCardStackEnabled = false
    public let onAbout: () -> Void
    public let onDismiss: () -> Void

    public init(onAbout: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.onAbout = onAbout
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Sync") {
                    Toggle("Sync data with iCloud", isOn: $syncEnabled)
                        .disabled(true)
                    Text("Coming soon")
                        .font(CCDesign.Typography.caption2)
                        .foregroundStyle(.secondary)
                }
                Section("Display") {
                    Toggle("Turn on advanced card stack", isOn: $advancedCardStackEnabled)
                        .disabled(true)
                    Text("Coming soon")
                        .font(CCDesign.Typography.caption2)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Rate on the App Store") {
                        // Opens App Store review — wired to real URL in Plan 3 polish.
                    }
                    Button("About developers", action: onAbout)
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
}
