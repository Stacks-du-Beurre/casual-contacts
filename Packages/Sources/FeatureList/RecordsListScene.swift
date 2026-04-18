import SwiftUI
import CoreModels
import DesignSystem
import Visuals

public struct RecordsListScene: View {

    public let store: any RecordStore
    public let paths: any CardPathProvider
    public let attitude: DeviceAttitude
    public let onTapRecord: (Record) -> Void
    public let onTapCreate: () -> Void
    public let onTapSettings: () -> Void

    @State private var searchText: String = ""
    @Environment(\.colorScheme) private var colorScheme

    public init(
        store: any RecordStore,
        paths: any CardPathProvider,
        attitude: DeviceAttitude,
        onTapRecord: @escaping (Record) -> Void,
        onTapCreate: @escaping () -> Void,
        onTapSettings: @escaping () -> Void
    ) {
        self.store = store
        self.paths = paths
        self.attitude = attitude
        self.onTapRecord = onTapRecord
        self.onTapCreate = onTapCreate
        self.onTapSettings = onTapSettings
    }

    @MainActor
    private var visibleRecords: [Record] {
        if searchText.isEmpty {
            return store.records
        }
        return store.search(searchText)
    }

    @MainActor
    private var isEmpty: Bool { store.records.isEmpty }

    /// Chrome inverts per mode — L2 on dark, D4 on light.
    /// Used for nav title, FAB fill, and right-item circle fill.
    private var chromePrimary: Color {
        colorScheme == .dark ? CCDesign.Colors.L2 : CCDesign.Colors.D4
    }

    /// Accent sits inside chrome primary — D4 on dark, L2 on light.
    /// Used for FAB `+` glyph and right-item ellipsis dots.
    private var chromeAccent: Color {
        colorScheme == .dark ? CCDesign.Colors.D4 : CCDesign.Colors.L2
    }

    /// Populated-list background. Empty state draws its own sunset gradient
    /// which covers this in the empty case.
    private var populatedBackground: Color {
        colorScheme == .dark ? CCDesign.Colors.D4 : CCDesign.Colors.L2
    }

    public var body: some View {
        NavigationStack {
            listContent
                .background(populatedBackground.ignoresSafeArea())
                .modifier(ConditionalSearchable(text: $searchText, isActive: !isEmpty))
                #if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
                #endif
                .safeAreaInset(edge: .top, spacing: 0) {
                    customNavBar
                }
        }
    }

    private var customNavBar: some View {
        // Empty state sits on the sunset gradient in both modes, so the
        // title stays L2; only the populated-list title inverts.
        let titleColor: Color = isEmpty ? CCDesign.Colors.L2 : chromePrimary
        return ZStack {
            Text("MY CONTACTS")
                .font(CCDesign.Typography.headline)
                .tracking(CCDesign.Typography.Tracking.headline)
                .foregroundStyle(titleColor)

            HStack {
                Spacer()
                ViewControllerButton(
                    action: onTapSettings,
                    fill: chromePrimary,
                    glyph: chromeAccent
                )
                .accessibilityLabel("Settings")
                .padding(.trailing, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }

    @ViewBuilder
    private var listContent: some View {
        ZStack(alignment: .bottomTrailing) {
            if isEmpty {
                EmptyStateView(paths: paths, onTap: onTapCreate)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleRecords) { record in
                            SmallCardListItem(record: record, attitude: attitude, paths: paths)
                                .onTapGesture { onTapRecord(record) }
                        }
                    }
                    .padding(.vertical, 12)
                }
            }

            AddButton(
                action: onTapCreate,
                fill: chromePrimary,
                glyph: chromeAccent
            )
            .padding(.trailing, 24)
            .padding(.bottom, 16)
            .accessibilityLabel("Add new contact")
            .accessibilityIdentifier("createRecordButton")
        }
    }
}

private struct ConditionalSearchable: ViewModifier {
    @Binding var text: String
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content.searchable(text: $text, prompt: "Search")
        } else {
            content
        }
    }
}
