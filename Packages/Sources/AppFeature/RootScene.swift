import SwiftUI
import CoreModels
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
    @State private var reduceMotionEnabled = false
    @State private var currentLocation: LocationInfo?
    @State private var currentTimeOfDay: TimeOfDay
    @State private var photoCache = PhotoCache()
    @Environment(\.scenePhase) private var scenePhase

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
            attitude: currentAttitude,
            timeOfDay: currentTimeOfDay,
            onTapRecord: { record in
                router.selectedRecordForMediumDetail = record
            },
            onTapCreate: {
                router.showingCreate = true
                Task {
                    currentLocation = (try? await environment.locationService.currentLocation()) ?? nil
                }
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
            photoFor: { photoCache.image(for: $0.photoID) },
            photoSizeFor: { photoCache.imageSize(for: $0.photoID) }
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
            Task {
                _ = await environment.locationService.requestAuthorization()
                currentLocation = (try? await environment.locationService.currentLocation()) ?? nil
            }
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
                Task {
                    currentLocation = (try? await environment.locationService.currentLocation()) ?? nil
                }
            case .inactive, .background:
                environment.motionService.stop()
            @unknown default:
                break
            }
        }
        .sheet(isPresented: $router.showingCreate) {
            let createdAt = Date()
            let metadata = environment.metadataGenerator.metadata(at: createdAt, location: currentLocation)
            CreateRecordScene(
                attitude: currentAttitude,
                paths: environment.cardPathProvider,
                faceDetectionService: environment.faceDetectionService,
                createdAt: createdAt,
                metadata: metadata,
                location: currentLocation,
                onCancel: { router.showingCreate = false },
                onSave: { draft in
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
                    router.editingRecord = record
                    router.selectedRecordForMediumDetail = nil
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
            SettingsSheet(onAbout: { router.showingAbout = true })
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
    #endif
}
