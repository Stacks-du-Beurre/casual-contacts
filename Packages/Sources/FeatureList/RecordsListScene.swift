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

    /// Title color per Figma: white on the sunset empty state, D4 on the populated light
    /// collection view, L2 on the populated dark collection view.
    @MainActor
    private var titleColor: Color {
        if isEmpty { return .white }
        return colorScheme == .dark ? CCDesign.Colors.L2 : CCDesign.Colors.D4
    }

    public var body: some View {
        NavigationStack {
            listContent
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .modifier(ConditionalSearchable(text: $searchText, isActive: !isEmpty))
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .principal) {
                        navTitle
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: onTapSettings) {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Settings")
                    }
                    #else
                    ToolbarItem(placement: .principal) {
                        navTitle
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: onTapSettings) {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Settings")
                    }
                    #endif
                }
                #if os(iOS)
                .modifier(NavBarBackground(isEmpty: isEmpty, colorScheme: colorScheme))
                #endif
        }
    }

    private var navTitle: some View {
        Text("MY CONTACTS")
            .font(CCDesign.Typography.headline)
            .tracking(CCDesign.Typography.Tracking.headline)
            .foregroundStyle(titleColor)
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

            Button(action: onTapCreate) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(CCDesign.Colors.D4))
            }
            .padding(16)
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

#if os(iOS)
private struct NavBarBackground: ViewModifier {
    let isEmpty: Bool
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        if isEmpty || colorScheme == .dark {
            content
                .toolbarBackground(.hidden, for: .navigationBar)
        } else {
            content
                .toolbarBackground(CCDesign.Colors.L2.opacity(0.8), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
#endif
