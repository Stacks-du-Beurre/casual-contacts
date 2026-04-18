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

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                if store.records.isEmpty {
                    EmptyStateView()
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
            }
            .navigationTitle("My Contacts")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onTapSettings) {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Settings")
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onTapSettings) {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Settings")
                }
                #endif
            }
        }
    }
}
