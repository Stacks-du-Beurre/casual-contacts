import SwiftUI
import CoreModels
import DesignSystem
import Visuals

/// Output of `RecordsListScene.bucketed(_:from:)`. `near` is everyone within
/// 1 mile of the origin (closest first); `far` is everyone else (closest
/// first; nil-location records sort to the end as `.infinity`). Ungrouped
/// orders set `near` empty.
public struct BucketedRecords: Sendable, Equatable {
    public let near: [Record]
    public let far: [Record]
    public init(near: [Record], far: [Record]) {
        self.near = near
        self.far = far
    }
}

public struct RecordsListScene: View {

    public let store: any RecordStore
    public let paths: any CardPathProvider
    public let attitude: DeviceAttitude
    public let timeOfDay: TimeOfDay
    /// Fires with the tapped record and its global CGRect at the moment of the
    /// tap. The host uses the rect as the starting position for an overlay
    /// animation that slides the card from its row to screen center.
    public let onTapRecord: (Record, CGRect) -> Void
    public let onTapCreate: () -> Void
    public let onTapSettings: () -> Void
    /// While a modal overlay is presenting a tapped card, the source row is
    /// hidden so the user doesn't see the same card in two places at once.
    public let hiddenRecordID: Record.ID?
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
    @State private var currentLocation: LocationInfo?
    @Binding private var pendingDeleteRecord: Record?
    @Environment(\.colorScheme) private var colorScheme

    /// Host-supplied lookup for the user's current coordinates. Returns nil
    /// when location is unauthorized or unavailable; the distance sort row
    /// is disabled while this is nil. Polled on appear and after the user
    /// taps the sort button (so a fresh fix arrives before the option
    /// picker draws). Default returns nil so previews/tests render the
    /// distance option as disabled without seeking a real fix.
    public let currentLocationProvider: @Sendable () async -> LocationInfo?

    public init(
        store: any RecordStore,
        paths: any CardPathProvider,
        attitude: DeviceAttitude,
        timeOfDay: TimeOfDay,
        onTapRecord: @escaping (Record, CGRect) -> Void,
        onTapCreate: @escaping () -> Void,
        onTapSettings: @escaping () -> Void,
        onScrollInteractionChange: @escaping (Bool) -> Void = { _ in },
        onEditRecord: @escaping (Record) -> Void = { _ in },
        photoFor: @escaping (Record) -> Image? = { _ in nil },
        photoSizeFor: @escaping (Record) -> CGSize? = { _ in nil },
        pendingDeleteRecord: Binding<Record?> = .constant(nil),
        hiddenRecordID: Record.ID? = nil,
        currentLocationProvider: @Sendable @escaping () async -> LocationInfo? = { nil }
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
        self._pendingDeleteRecord = pendingDeleteRecord
        self.hiddenRecordID = hiddenRecordID
        self.currentLocationProvider = currentLocationProvider
    }

    @MainActor
    private var visibleRecords: [Record] {
        let base = searchText.isEmpty ? store.records : store.search(searchText)
        return Self.sorted(base, by: sortOption, from: currentLocation)
    }

    /// Bucketed view of `visibleRecords` for the distance sort. When the
    /// option isn't `.distance` or no current location is available, `near`
    /// is empty and `far` holds everything in the option's normal order so
    /// the list renders as a single ungrouped stack.
    @MainActor
    private var bucketedVisibleRecords: BucketedRecords {
        let base = searchText.isEmpty ? store.records : store.search(searchText)
        if sortOption == .distance, let origin = currentLocation {
            return Self.bucketed(base, from: origin)
        } else {
            return BucketedRecords(near: [], far: Self.sorted(base, by: sortOption, from: currentLocation))
        }
    }

    static func sorted(
        _ records: [Record],
        by option: SortOption,
        from origin: LocationInfo? = nil
    ) -> [Record] {
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
        case .distance:
            // Records without a fix sort to the bottom (treated as ∞). When
            // origin is unavailable the picker should have prevented this
            // option from being selected — fall through to alphabetical.
            guard let origin else {
                return Self.sorted(records, by: .alphabetical)
            }
            return records.sorted { lhs, rhs in
                let lDist = lhs.location.map { $0.distanceMeters(to: origin) } ?? .infinity
                let rDist = rhs.location.map { $0.distanceMeters(to: origin) } ?? .infinity
                return lDist < rDist
            }
        }
    }

    /// Splits `records` into a "within 1 mile of `origin`" group and a
    /// "further than 1 mile or location unknown" group. Both groups are
    /// closest-first within themselves so the stitched order reads as a
    /// single proximity ramp once a divider is dropped between them.
    static func bucketed(_ records: [Record], from origin: LocationInfo?) -> BucketedRecords {
        guard let origin else {
            return BucketedRecords(near: [], far: Self.sorted(records, by: .distance, from: nil))
        }
        var nearWithDistance: [(Record, Double)] = []
        var farWithDistance: [(Record, Double)] = []
        for record in records {
            guard let loc = record.location else {
                farWithDistance.append((record, .infinity))
                continue
            }
            let meters = loc.distanceMeters(to: origin)
            if meters <= LocationInfo.metersInMile {
                nearWithDistance.append((record, meters))
            } else {
                farWithDistance.append((record, meters))
            }
        }
        nearWithDistance.sort { $0.1 < $1.1 }
        farWithDistance.sort { $0.1 < $1.1 }
        return BucketedRecords(
            near: nearWithDistance.map(\.0),
            far: farWithDistance.map(\.0)
        )
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
                        isDistanceEnabled: currentLocation != nil,
                        onAdvanced: { isSortingSheetPresented = false },
                        onDismiss: { isSortingSheetPresented = false }
                    )
                    .zIndex(1)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSortingSheetPresented)
            .task {
                // One-shot location fetch on appear so the distance sort row
                // is enabled before the user opens the picker. The button's
                // own action refreshes again on tap.
                let fix = await currentLocationProvider()
                await MainActor.run { currentLocation = fix }
            }
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
                        action: {
                            // Refresh on each open so a fresh fix arrives before
                            // the picker draws — the row enables/disables based
                            // on `currentLocation != nil`.
                            Task {
                                let fix = await currentLocationProvider()
                                await MainActor.run {
                                    currentLocation = fix
                                    if fix == nil, sortOption == .distance {
                                        sortOption = .alphabetical
                                    }
                                }
                            }
                            isSortingSheetPresented = true
                        },
                        glyph: chromePrimary
                    )
                    .accessibilityLabel("Sorting")
                    .accessibilityIdentifier("sortButton")
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
                let buckets = bucketedVisibleRecords
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(buckets.near) { record in
                            RecordCardRow(
                                record: record,
                                attitude: attitude,
                                paths: paths,
                                photo: photoFor(record),
                                photoSize: photoSizeFor(record),
                                isHidden: hiddenRecordID == record.id,
                                onTap: onTapRecord
                            )
                        }
                        if !buckets.near.isEmpty {
                            // 1-mile group separator. Token color matches
                            // Figma `Line 60` from `D_Collection_View` /
                            // `L_Collection_View`. Spans the full list
                            // width — the LazyVStack's 16pt horizontal
                            // padding already insets the line to the same
                            // edges as the cards.
                            Rectangle()
                                .fill(navBarBottomLineColor)
                                .frame(height: 0.5)
                                .accessibilityHidden(true)
                        }
                        ForEach(buckets.far) { record in
                            RecordCardRow(
                                record: record,
                                attitude: attitude,
                                paths: paths,
                                photo: photoFor(record),
                                photoSize: photoSizeFor(record),
                                isHidden: hiddenRecordID == record.id,
                                onTap: onTapRecord
                            )
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
            .zoomSource(.createButton)
        }
    }

}

/// One row of the records list. Owns its own `@State` for the card's current
/// global frame so tap-time frame capture can't cross-contaminate between rows
/// the way a single shared dictionary could.
private struct RecordCardRow: View {
    let record: Record
    let attitude: DeviceAttitude
    let paths: any CardPathProvider
    let photo: Image?
    let photoSize: CGSize?
    let isHidden: Bool
    let onTap: (Record, CGRect) -> Void

    @State private var frame: CGRect = .zero

    var body: some View {
        CardView(
            record: record,
            size: .small,
            attitude: attitude,
            paths: paths,
            photo: photo,
            photoSize: photoSize
        )
        .frame(height: 211)
        // Rasterize each card's full blend stack into a single Metal texture
        // per row instead of paying ~20 offscreen passes per card per frame
        // for the hologram blur + blend chains. opaque: false preserves the
        // alpha so the rounded clip below stays correct.
        .drawingGroup(opaque: false)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("recordCard_\(record.id.uuidString)")
        .opacity(isHidden ? 0 : 1)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { frame = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, new in
                        frame = new
                    }
            }
        )
        .onTapGesture { onTap(record, frame) }
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

