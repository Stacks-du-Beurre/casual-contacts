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

    /// Inject an already-wired `AppEnvironment` (e.g. `.production()` from the
    /// app target, or `.testing()` in previews/tests). Registering bundled fonts
    /// is idempotent, so we do it here rather than in the app target.
    public init(environment: AppEnvironment) {
        _environment = State(initialValue: environment)
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
            onTapRecord: { record in
                router.selectedRecordForMediumDetail = record
            },
            onTapCreate: {
                router.showingCreate = true
            },
            onTapSettings: {
                router.showingSettings = true
            }
        )
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
                currentAttitude = .zero
            }
        }
        .sheet(isPresented: $router.showingCreate) {
            CreateRecordScene(
                attitude: currentAttitude,
                paths: environment.cardPathProvider,
                onCancel: { router.showingCreate = false },
                onSave: { draft in
                    Task {
                        let metadata = environment.metadataGenerator.metadata(
                            at: Date(),
                            location: draft.location
                        )
                        _ = try? await environment.recordStore.create(draft, metadata: metadata)
                        router.showingCreate = false
                    }
                }
            )
        }
        .sheet(item: $router.selectedRecordForMediumDetail) { record in
            MediumDetailSheet(
                record: record,
                attitude: currentAttitude,
                paths: environment.cardPathProvider,
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
