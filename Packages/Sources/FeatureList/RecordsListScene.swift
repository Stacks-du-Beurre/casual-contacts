import SwiftUI
import CoreModels
import DesignSystem
import Visuals

public struct RecordsListScene: View {

    public let store: any RecordStore
    public let paths: any CardPathProvider
    public let attitude: DeviceAttitude
    public let timeOfDay: TimeOfDay
    public let onTapRecord: (Record) -> Void
    public let onTapCreate: () -> Void
    public let onTapSettings: () -> Void
    /// Called with `true` when the user begins interacting with the scroll
    /// (touch-down / scrolling / decelerating) and `false` when the scroll
    /// returns to idle. Caller pauses the gyro pipeline accordingly so cards
    /// stop re-evaluating the moment the user touches the list.
    public let onScrollInteractionChange: (Bool) -> Void
    public let onEditRecord: (Record) -> Void
    /// Lookup for a record's photo image. Host (AppFeature) provides a cache
    /// that loads PhotoIDs via PhotoStore; default returns nil for previews.
    public let photoFor: (Record) -> Image?
    /// Lookup for a record's photo pixel size, paired with `photoFor`. Needed
    /// by `PhotoLayer` to offset the image so the detected face sits at the
    /// container center.
    public let photoSizeFor: (Record) -> CGSize?

    @State private var searchText: String = ""
    @State private var sortOption: SortOption = .alphabetical
    @State private var isSortingSheetPresented: Bool = false
    @State private var menuRecordID: Record.ID?
    @State private var pendingDeleteRecord: Record?
    @Environment(\.colorScheme) private var colorScheme

    public init(
        store: any RecordStore,
        paths: any CardPathProvider,
        attitude: DeviceAttitude,
        timeOfDay: TimeOfDay,
        onTapRecord: @escaping (Record) -> Void,
        onTapCreate: @escaping () -> Void,
        onTapSettings: @escaping () -> Void,
        onScrollInteractionChange: @escaping (Bool) -> Void = { _ in },
        onEditRecord: @escaping (Record) -> Void = { _ in },
        photoFor: @escaping (Record) -> Image? = { _ in nil },
        photoSizeFor: @escaping (Record) -> CGSize? = { _ in nil }
    ) {
        self.store = store
        self.paths = paths
        self.attitude = attitude
        self.timeOfDay = timeOfDay
        self.onTapRecord = onTapRecord
        self.onTapCreate = onTapCreate
        self.onTapSettings = onTapSettings
        self.onScrollInteractionChange = onScrollInteractionChange
        self.onEditRecord = onEditRecord
        self.photoFor = photoFor
        self.photoSizeFor = photoSizeFor
    }

    @MainActor
    private var visibleRecords: [Record] {
        let base = searchText.isEmpty ? store.records : store.search(searchText)
        return Self.sorted(base, by: sortOption)
    }

    static func sorted(_ records: [Record], by option: SortOption) -> [Record] {
        switch option {
        case .alphabetical:
            return records.sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .dateCreated:
            return records.sorted { $0.createdAt > $1.createdAt }
        case .timeCreated:
            let cal = Calendar.current
            return records.sorted { lhs, rhs in
                let lc = cal.dateComponents([.hour, .minute, .second], from: lhs.createdAt)
                let rc = cal.dateComponents([.hour, .minute, .second], from: rhs.createdAt)
                let lSeconds = (lc.hour ?? 0) * 3600 + (lc.minute ?? 0) * 60 + (lc.second ?? 0)
                let rSeconds = (rc.hour ?? 0) * 3600 + (rc.minute ?? 0) * 60 + (rc.second ?? 0)
                return lSeconds < rSeconds
            }
        }
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

    /// Populated-list background. Empty state draws its own time-of-day
    /// gradient which covers this in the empty case. Matches Figma
    /// `L_Collection_View` (L2 = #E9EAF1) and `D_Collection_View` (D3 = #282A30).
    private var populatedBackground: Color {
        colorScheme == .dark ? CCDesign.Colors.D3 : CCDesign.Colors.L2
    }

    /// Bottom hairline of the nav bar — Figma `Line 60` inside
    /// `L_Collection_View` / `D_Collection_View`. 0.5pt stroke.
    private var navBarBottomLineColor: Color {
        colorScheme == .dark ? CCDesign.Colors.D0 : CCDesign.Colors.L3
    }

    public var body: some View {
        GeometryReader { proxy in
            // Same anchor as EmptyStateView: 375pt iPhone 11 Pro canvas, floor
            // at Figma size, cap at 1.3× so iPad widths don't overshoot.
            let canvasScale = min(max(proxy.size.width / 375, 1.0), 1.3)
            ZStack {
                NavigationStack {
                    listContent
                        .background(populatedBackground.ignoresSafeArea())
                        .modifier(ConditionalSearchable(text: $searchText, isActive: !isEmpty))
                        #if os(iOS)
                        .toolbar(.hidden, for: .navigationBar)
                        #endif
                        .safeAreaInset(edge: .top, spacing: 0) {
                            customNavBar(scale: canvasScale)
                        }
                }

                if isSortingSheetPresented {
                    DefaultSortingSheet(
                        selected: $sortOption,
                        onAdvanced: { isSortingSheetPresented = false },
                        onDismiss: { isSortingSheetPresented = false }
                    )
                    .zIndex(1)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSortingSheetPresented)
            .alert(
                "Delete contact?",
                isPresented: Binding(
                    get: { pendingDeleteRecord != nil },
                    set: { if !$0 { pendingDeleteRecord = nil } }
                ),
                presenting: pendingDeleteRecord
            ) { record in
                Button("Delete", role: .destructive) {
                    pendingDeleteRecord = nil
                    Task { try? await store.delete(id: record.id) }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteRecord = nil
                }
            } message: { record in
                let name = record.name.isEmpty ? "This contact" : record.name.capitalized
                Text("\(name) will be permanently removed.")
            }
        }
    }

    private func customNavBar(scale: CGFloat) -> some View {
        // Empty state sits on the time-of-day gradient in both modes, so the
        // title stays L2; only the populated-list title inverts.
        let titleColor: Color = isEmpty ? CCDesign.Colors.L2 : chromePrimary
        return ZStack {
            Text("MY CONTACTS")
                .font(.custom("CormorantSC-Bold", size: 17 * scale, relativeTo: .headline))
                .tracking(CCDesign.Typography.Tracking.headline * scale)
                .foregroundStyle(titleColor)

            HStack {
                if !isEmpty {
                    SortingButton(
                        action: { isSortingSheetPresented = true },
                        glyph: chromePrimary
                    )
                    .accessibilityLabel("Sorting")
                    .padding(.leading, 10)
                }
                Spacer()
                ViewControllerButton(
                    action: onTapSettings,
                    fill: chromePrimary,
                    glyph: chromeAccent,
                    scale: scale
                )
                .accessibilityLabel("Settings")
                .padding(.trailing, 10)
            }
        }
        .frame(maxWidth: .infinity)
        // Bar height scales with the same factor so the scaled button sits
        // inside the chrome instead of overflowing it.
        .frame(height: 44 * scale)
        .background {
            if !isEmpty {
                populatedBackground.ignoresSafeArea(edges: .top)
            }
        }
        .overlay(alignment: .bottom) {
            if !isEmpty {
                Rectangle()
                    .fill(navBarBottomLineColor)
                    .frame(height: 0.5)
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        ZStack(alignment: .bottomTrailing) {
            if isEmpty {
                EmptyStateView(paths: paths, timeOfDay: timeOfDay, attitude: attitude, onTap: onTapCreate)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(visibleRecords) { record in
                            CardView(
                                record: record,
                                size: .small,
                                attitude: attitude,
                                paths: paths,
                                photo: photoFor(record),
                                photoSize: photoSizeFor(record)
                            )
                            .frame(height: 211)
                            // Rasterize each card's full blend stack into a
                            // single Metal texture per row instead of paying
                            // ~20 offscreen passes per card per frame for the
                            // hologram blur + blend chains. The scroll-pause
                            // we ship at the motion-service level keeps the
                            // texture cache valid through the gesture; outside
                            // scroll, the throttled gyro rate (≤30 Hz) bounds
                            // re-rasterization. opaque: false preserves the
                            // alpha so the rounded clip below stays correct.
                            .drawingGroup(opaque: false)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay {
                                if menuRecordID == record.id {
                                    RecordActionMenu(
                                        onEdit: {
                                            let editing = record
                                            menuRecordID = nil
                                            onEditRecord(editing)
                                        },
                                        onDelete: {
                                            menuRecordID = nil
                                            pendingDeleteRecord = record
                                        }
                                    )
                                    .fixedSize()
                                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .center)))
                                }
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("recordCard_\(record.id.uuidString)")
                            .onTapGesture {
                                menuRecordID = (menuRecordID == record.id) ? nil : record.id
                            }
                            .zIndex(menuRecordID == record.id ? 1 : 0)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                #if os(iOS)
                // `.interacting` fires the moment the user touches the scroll
                // surface (before any movement is detected), so the gyro
                // pipeline pauses on touch-down — not just once scrolling
                // begins. `.idle` after lift+decel resumes it.
                .onScrollPhaseChange { _, phase in
                    onScrollInteractionChange(phase != .idle)
                }
                #endif
            }

            AddButton(
                action: onTapCreate,
                fill: chromePrimary,
                glyph: chromeAccent
            )
            .padding(.trailing, 24)
            .padding(.bottom, 32)
            .accessibilityLabel("Add new contact")
            .accessibilityIdentifier("createRecordButton")
        }
    }

}

private struct RecordActionMenu: View {
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onEdit) {
                rowLabel("Edit", role: nil)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recordActionEdit")

            Divider()
                .background(Color.white.opacity(0.12))

            Button(action: onDelete) {
                rowLabel("Delete", role: .destructive)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recordActionDelete")
        }
        .frame(width: 160)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }

    private func rowLabel(_ text: String, role: ButtonRole?) -> some View {
        Text(text.uppercased())
            .font(CCDesign.Typography.headline)
            .tracking(CCDesign.Typography.Tracking.headline)
            .foregroundStyle(role == .destructive ? Color.red : CCDesign.Colors.L0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
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

