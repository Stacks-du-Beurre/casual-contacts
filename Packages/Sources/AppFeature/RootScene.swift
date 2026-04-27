import SwiftUI
import CoreModels
import DesignSystem
import Visuals
import FeatureList
import FeatureCreate
import FeatureDetail
import FeatureSettings
#if os(iOS)
import UIKit
#endif

/// The root SwiftUI `Scene` that composes every feature module in the app.
///
/// `RootScene` owns the `NavigationRouter` (sheet/presentation flags) and keeps the
/// current `DeviceAttitude` in sync with the injected `MotionService`. It does
/// **not** build its own `AppEnvironment` — the app target (or a test harness)
/// passes one in, which keeps this module free of iOS-only `#if` at init time.
public struct RootScene: Scene {

    @State private var environment: AppEnvironment
    @State private var router = NavigationRouter()
    @State private var currentAttitude = DeviceAttitude.zero
    /// Snapshot of `currentAttitude` captured the moment a card modal opens,
    /// fed to the list behind the backdrop so its rows freeze in place while
    /// the modal's own card continues reading the live stream.
    @State private var frozenListAttitude = DeviceAttitude.zero
    @State private var reduceMotionEnabled = false
    @State private var currentTimeOfDay: TimeOfDay
    @State private var photoCache = PhotoCache()
    @State private var pendingDeleteRecord: Record?
    /// Drives the alert shown when "Add 4 nearby records" runs without a
    /// usable location fix (denied authorization or fix failure). Setting
    /// this to non-nil presents the alert with the message as the body.
    @State private var nearbyDebugError: String?
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var zoomNamespace

    /// Inject an already-wired `AppEnvironment` (e.g. `.production()` from the
    /// app target, or `.testing()` in previews/tests). Registering bundled fonts
    /// is idempotent, so we do it here rather than in the app target.
    public init(environment: AppEnvironment) {
        _environment = State(initialValue: environment)
        // Seed the current time-of-day from the metadata generator so the
        // empty-state gradient paints the correct PNG on first frame. Refreshed
        // on every `.active` scene phase so it stays accurate across dawn/dusk
        // boundaries while the app is open.
        let seed = environment.metadataGenerator.metadata(at: Date(), location: nil).timeOfDay
        _currentTimeOfDay = State(initialValue: seed)
        FontRegistration.registerBundledFonts()
    }

    public var body: some Scene {
        WindowGroup {
            #if os(iOS)
            rootContent
                .environment(\.zoomNamespace, zoomNamespace)
                .preferredColorScheme(ScreenshotMode.appearanceOverride)
                .task {
                    await ScreenshotMode.seedIfNeeded(into: environment)
                }
            #else
            Text("RootScene is iOS-only")
            #endif
        }
    }

    #if os(iOS)
    @MainActor
    @ViewBuilder
    private var rootContent: some View {
        RecordsListScene(
            store: environment.recordStore,
            paths: environment.cardPathProvider,
            attitude: router.tappedRecord == nil ? currentAttitude : frozenListAttitude,
            timeOfDay: currentTimeOfDay,
            onTapRecord: { record, frame in
                frozenListAttitude = currentAttitude
                router.tappedRecordSourceFrame = frame
                router.tappedRecord = record
            },
            onTapCreate: {
                router.showingCreate = true
            },
            onTapSettings: {
                router.showingSettings = true
            },
            onScrollInteractionChange: { interacting in
                // Pause the gyro pipeline the moment the user touches the
                // list (not just once scrolling begins) and resume on idle.
                // Reduce-motion takes precedence — never resume CoreMotion if
                // the user has it on.
                if interacting {
                    environment.motionService.stop()
                } else if !reduceMotionEnabled {
                    environment.motionService.start()
                }
            },
            onEditRecord: { record in
                router.editingRecord = record
            },
            photoFor: { photoCache.image(for: $0.photoID) },
            photoSizeFor: { photoCache.imageSize(for: $0.photoID) },
            pendingDeleteRecord: $pendingDeleteRecord,
            hiddenRecordID: router.tappedRecord?.id,
            currentLocationProvider: { [locationService = environment.locationService] in
                guard locationService.currentAuthorization() == .authorized else { return nil }
                return try? await locationService.currentLocation()
            }
        )
        .onChange(of: environment.recordStore.records.map(\.photoID)) { _, _ in
            Task { await photoCache.preload(environment.recordStore.records, using: environment.photoStore) }
        }
        .task {
            await photoCache.preload(environment.recordStore.records, using: environment.photoStore)
        }
        .task {
            reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            environment.motionService.start()
            for await raw in environment.motionService.attitude {
                // Re-read @State each tick so mid-session toggles from the
                // UIAccessibility notification propagate on the next gyro sample.
                let enabled = reduceMotionEnabled
                currentAttitude = ReducedMotionAdapter.attitude(raw: raw, reduceMotionEnabled: enabled)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)) { _ in
            reduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            if reduceMotionEnabled {
                // Stop the CoreMotion delegate so no more gyro callbacks fire.
                // The stream itself stays open; ReducedMotionAdapter clamps any
                // straggler sample to .zero.
                environment.motionService.stop()
                currentAttitude = .zero
            } else {
                // Resume gyro sampling on the existing stream.
                environment.motionService.start()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Stop CoreMotion the moment the app loses focus (lock screen,
            // Control Center, app switcher, background). Resuming requires
            // both `.active` and reduce-motion off.
            switch newPhase {
            case .active:
                if !reduceMotionEnabled {
                    environment.motionService.start()
                }
                // Refresh time-of-day so the empty-state gradient tracks wall
                // time across foreground returns (e.g. re-opening at dusk
                // after launching at midday).
                currentTimeOfDay = environment.metadataGenerator.metadata(
                    at: Date(),
                    location: nil
                ).timeOfDay
            case .inactive, .background:
                environment.motionService.stop()
            @unknown default:
                break
            }
        }
        .sheet(isPresented: $router.showingCreate) {
            let createdAt = Date()
            let metadata = environment.metadataGenerator.metadata(at: createdAt, location: nil)
            CreateRecordScene(
                attitude: currentAttitude,
                paths: environment.cardPathProvider,
                faceDetectionService: environment.faceDetectionService,
                createdAt: createdAt,
                metadata: metadata,
                location: nil,
                locationProvider: { [locationService = environment.locationService] in
                    guard locationService.currentAuthorization() == .authorized else { return nil }
                    return try? await locationService.currentLocation()
                },
                onCancel: { router.showingCreate = false },
                onSave: { outcome in
                    guard case let .create(draft) = outcome else { return }
                    Task {
                        let photoID: PhotoID?
                        if let data = draft.photo {
                            photoID = try? await environment.photoStore.save(data)
                        } else {
                            photoID = nil
                        }
                        let saveMetadata = environment.metadataGenerator.metadata(
                            at: Date(),
                            location: draft.location
                        )
                        _ = try? await environment.recordStore.create(
                            draft,
                            metadata: saveMetadata,
                            photoID: photoID
                        )
                        router.showingCreate = false
                    }
                }
            )
            .presentationCornerRadius(12)
            .zoomDestination(.createButton)
        }
        .overlay {
            if let tapped = router.tappedRecord {
                TappedCardModalScene(
                    record: tapped,
                    sourceFrame: router.tappedRecordSourceFrame,
                    attitude: currentAttitude,
                    paths: environment.cardPathProvider,
                    photo: photoCache.image(for: tapped.photoID),
                    photoSize: photoCache.imageSize(for: tapped.photoID),
                    onEdit: { router.editingRecord = tapped },
                    onDelete: { pendingDeleteRecord = tapped },
                    onDismiss: { router.tappedRecord = nil }
                )
                .transition(.identity)
            }
        }
        .sheet(item: $router.selectedRecordForMediumDetail) { record in
            MediumDetailSheet(
                record: record,
                attitude: currentAttitude,
                paths: environment.cardPathProvider,
                photo: photoCache.image(for: record.photoID),
                photoSize: photoCache.imageSize(for: record.photoID),
                onExpand: {
                    router.selectedRecordForMediumDetail = nil
                    router.selectedRecordForLargeDetail = record
                },
                onEdit: {
                    // Dismiss the medium sheet first; defer presenting the
                    // edit sheet a tick so SwiftUI doesn't drop the second
                    // presentation while the first is still dismissing.
                    router.selectedRecordForMediumDetail = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        router.editingRecord = record
                    }
                },
                onDelete: {
                    Task {
                        try? await environment.recordStore.delete(id: record.id)
                        router.selectedRecordForMediumDetail = nil
                    }
                },
                onDismiss: {
                    router.selectedRecordForMediumDetail = nil
                }
            )
        }
        .sheet(item: $router.editingRecord) { record in
            EditingSheetContent(
                record: record,
                environment: environment,
                photoCache: photoCache,
                attitude: currentAttitude,
                onFinish: { router.editingRecord = nil }
            )
            .presentationCornerRadius(12)
        }
        .fullScreenCover(item: $router.selectedRecordForLargeDetail) { record in
            LargeDetailScene(
                record: record,
                attitude: currentAttitude,
                paths: environment.cardPathProvider,
                photo: photoCache.image(for: record.photoID),
                photoSize: photoCache.imageSize(for: record.photoID),
                onEdit: {
                    router.editingRecord = record
                    router.selectedRecordForLargeDetail = nil
                },
                onDelete: {
                    Task {
                        try? await environment.recordStore.delete(id: record.id)
                        router.selectedRecordForLargeDetail = nil
                    }
                },
                onDismiss: {
                    router.selectedRecordForLargeDetail = nil
                }
            )
        }
        .sheet(isPresented: $router.showingSettings) {
            SettingsSheet(
                onAbout: { router.showingAbout = true },
                onAddDebugRecords: addDebugRecords,
                onAddNearbyDebugRecords: addNearbyDebugRecords,
                onRemoveDebugRecords: removeDebugRecords,
                onOpenLetterGallery: openLetterGallery,
                readLocationAuthorization: { environment.locationService.currentAuthorization() },
                requestLocationAuthorization: { await environment.locationService.requestAuthorization() },
                openSystemSettings: openSystemSettings
            )
                .presentationCornerRadius(12)
        }
        #if DEBUG
        .fullScreenCover(isPresented: $router.showingDebugLetterGallery) {
            DebugLetterGalleryScene(
                paths: environment.cardPathProvider,
                attitude: currentAttitude,
                onDismiss: { router.showingDebugLetterGallery = false }
            )
        }
        #endif
        .alert(
            "Location Required",
            isPresented: Binding(
                get: { nearbyDebugError != nil },
                set: { if !$0 { nearbyDebugError = nil } }
            ),
            presenting: nearbyDebugError
        ) { _ in
            Button("OK", role: .cancel) { nearbyDebugError = nil }
        } message: { message in
            Text(message)
        }
        .sheet(isPresented: $router.showingAbout) {
            NavigationStack {
                AboutView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { router.showingAbout = false }
                        }
                    }
            }
        }
        .environment(environment)
    }

    /// Bulk-inserts the seven hand-authored fixtures from
    /// `DebugRecordSeeder` (one per `TimeOfDay`) into the live record
    /// store. Wired to a developer-settings row for QA.
    private func addDebugRecords() {
        Task {
            let store = environment.recordStore
            for record in DebugRecordSeeder.records {
                try? await store.insert(record)
            }
        }
    }

    /// Deletes only records whose IDs match the seeder's reserved UUID
    /// list — production records (random UUIDs) are unaffected. Cleans
    /// both the city seeds (`DEBC1100-…`) and the nearby seeds
    /// (`DEBC1101-…`).
    private func removeDebugRecords() {
        Task {
            let store = environment.recordStore
            for id in DebugRecordSeeder.ids + DebugRecordSeeder.nearbyIDs {
                try? await store.delete(id: id)
            }
        }
    }

    /// Resolves the user's current location and inserts four debug records
    /// scattered randomly within 1 mile. Surfaces an alert and bails if
    /// authorization is not granted or the fix fails — we never seed
    /// against a synthetic origin because the point of the row is to
    /// validate the distance sort against *real* nearby coordinates.
    private func addNearbyDebugRecords() {
        Task {
            let service = environment.locationService
            guard service.currentAuthorization() == .authorized else {
                await MainActor.run {
                    nearbyDebugError = "Enable location access for Casual Contacts in iOS Settings to seed nearby records."
                }
                return
            }
            let origin: LocationInfo?
            do {
                origin = try await service.currentLocation()
            } catch {
                origin = nil
            }
            guard let origin else {
                await MainActor.run {
                    nearbyDebugError = "Couldn't determine your current location. Try again with a clearer GPS signal."
                }
                return
            }
            let store = environment.recordStore
            for record in DebugRecordSeeder.nearbyRecords(around: origin) {
                try? await store.insert(record)
            }
        }
    }

    /// Dismisses the Settings sheet and presents the 78-card letter-gallery
    /// diagnostic. Mirrors the dismiss-then-present timing used by the
    /// edit-from-settings flow so SwiftUI doesn't drop the second
    /// presentation while the first is still dismissing. The fullScreenCover
    /// itself is `#if DEBUG`-gated, so this is a no-op in release builds.
    private func openLetterGallery() {
        router.showingSettings = false
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            router.showingDebugLetterGallery = true
        }
    }

    /// Opens iOS Settings deep-linked to this app's permissions page so
    /// the user can re-enable a previously-denied authorization (which
    /// iOS otherwise won't re-prompt for in-app).
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    #endif
}

#if os(iOS)
@MainActor
private struct EditingSheetContent: View {
    let record: Record
    let environment: AppEnvironment
    @Bindable var photoCache: PhotoCache
    let attitude: DeviceAttitude
    let onFinish: () -> Void

    @State private var photoData: Data?
    @State private var didLoad = false

    var body: some View {
        Group {
            if didLoad {
                CreateRecordScene(
                    editing: record,
                    attitude: attitude,
                    paths: environment.cardPathProvider,
                    faceDetectionService: environment.faceDetectionService,
                    photoData: photoData,
                    photoFocus: record.photoFocus,
                    onCancel: onFinish,
                    onSave: { outcome in
                        guard case let .update(updated, newPhotoData, newPhotoFocus) = outcome else {
                            onFinish()
                            return
                        }
                        Task {
                            var resolved = updated
                            if newPhotoData != photoData {
                                if let bytes = newPhotoData {
                                    if let savedID = try? await environment.photoStore.save(bytes) {
                                        resolved.photoID = savedID
                                        resolved.photoFocus = newPhotoFocus
                                        // Only remove the old file once the new one is safely persisted.
                                        if let oldID = record.photoID, oldID != savedID {
                                            try? await environment.photoStore.delete(oldID)
                                            photoCache.invalidate(oldID)
                                        }
                                    }
                                    // If save failed, leave resolved.photoID == record.photoID (untouched)
                                    // so the record still points at a valid file.
                                } else {
                                    // User explicitly cleared the photo.
                                    resolved.photoID = nil
                                    resolved.photoFocus = nil
                                    if let oldID = record.photoID {
                                        try? await environment.photoStore.delete(oldID)
                                        photoCache.invalidate(oldID)
                                    }
                                }
                            }
                            try? await environment.recordStore.update(resolved)
                            // Invalidate the cache for this slot so the list reloads
                            // the new bytes.
                            photoCache.invalidate(resolved.photoID)
                            await photoCache.preload([resolved], using: environment.photoStore)
                            onFinish()
                        }
                    }
                )
            } else {
                Color.clear
            }
        }
        .task {
            if let id = record.photoID {
                photoData = try? await environment.photoStore.load(id)
            }
            didLoad = true
        }
    }
}
#endif
