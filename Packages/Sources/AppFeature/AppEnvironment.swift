import Foundation
import SwiftUI
import SwiftData
import Observation
import CoreModels
import Storage
import Services
import Visuals

/// Single root container for every service a Feature module needs.
///
/// Wired once per process (app target) and injected into the SwiftUI environment
/// via `.environment(appEnvironment)`. Views then pull whichever services they need
/// through `@Environment(AppEnvironment.self)`. Features see only the `CoreModels`
/// protocols; the concrete `SwiftDataRecordStore` / `CoreLocationService` / etc.
/// types never leak past this module.
@MainActor
@Observable
public final class AppEnvironment {

    public let recordStore: any RecordStore
    public let photoStore: any PhotoStore
    public let locationService: any LocationService
    public let locationPermissionPrimerStore: any LocationPermissionPrimerStore
    public let motionService: any MotionService
    public let metadataGenerator: any MetadataGenerator
    public let cardPathProvider: any CardPathProvider
    public let faceDetectionService: any FaceDetectionService

    public init(
        recordStore: any RecordStore,
        photoStore: any PhotoStore,
        locationService: any LocationService,
        locationPermissionPrimerStore: any LocationPermissionPrimerStore,
        motionService: any MotionService,
        metadataGenerator: any MetadataGenerator,
        cardPathProvider: any CardPathProvider,
        faceDetectionService: any FaceDetectionService
    ) {
        self.recordStore = recordStore
        self.photoStore = photoStore
        self.locationService = locationService
        self.locationPermissionPrimerStore = locationPermissionPrimerStore
        self.motionService = motionService
        self.metadataGenerator = metadataGenerator
        self.cardPathProvider = cardPathProvider
        self.faceDetectionService = faceDetectionService
    }

    /// Production wiring: SwiftData persistence, on-disk photo storage,
    /// CoreLocation + CoreMotion services, real metadata, and the generated
    /// `RealCardPathProvider`.
    ///
    /// On macOS `CoreMotionService` is unavailable (CoreMotion is iOS-only), so
    /// the macOS build of this factory is disabled — the app ships iOS-only.
    #if !os(macOS)
    public static func production() throws -> AppEnvironment {
        let container = try ModelContainer(
            for: PersistedRecord.self,
            configurations: ModelConfiguration()
        )
        let photoRoot = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Photos", isDirectory: true)

        return AppEnvironment(
            recordStore: SwiftDataRecordStore(container: container),
            photoStore: FileSystemPhotoStore(rootURL: photoRoot),
            locationService: CoreLocationService(),
            locationPermissionPrimerStore: UserDefaultsLocationPermissionPrimerStore(),
            motionService: CoreMotionService(),
            metadataGenerator: SystemMetadataGenerator(),
            cardPathProvider: RealCardPathProvider(),
            faceDetectionService: VisionFaceDetectionService()
        )
    }

    @MainActor
    public static func productionOrUITestReset() throws -> AppEnvironment {
        let args = ProcessInfo.processInfo.arguments
        if ScreenshotMode.isEnabled {
            return try screenshotEnvironment()
        }
        if let idx = args.firstIndex(of: "-UITestReset"),
           idx + 1 < args.count,
           args[idx + 1] == "YES" {
            return try uiTestResetEnvironment()
        }
        return try production()
    }

    @MainActor
    private static func uiTestResetEnvironment() throws -> AppEnvironment {
        let container = try ModelContainer(
            for: PersistedRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let photoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CCUITestPhotos-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: photoRoot, withIntermediateDirectories: true)

        return AppEnvironment(
            recordStore: SwiftDataRecordStore(container: container),
            photoStore: FileSystemPhotoStore(rootURL: photoRoot),
            locationService: CoreLocationService(),
            locationPermissionPrimerStore: UserDefaultsLocationPermissionPrimerStore(),
            motionService: CoreMotionService(),
            metadataGenerator: SystemMetadataGenerator(),
            cardPathProvider: RealCardPathProvider(),
            faceDetectionService: VisionFaceDetectionService()
        )
    }

    /// In-memory store, no real CoreLocation/CoreMotion. The motion service
    /// emits `.zero` so cards don't tilt mid-screenshot. The location
    /// service returns a fixed San Francisco origin so the distance sort
    /// renders the "≤ 1 mile" divider deterministically. Time-of-day and
    /// moon phase come baked into each seed record, so the metadata
    /// generator's wall-clock dependence doesn't affect the captured frame.
    @MainActor
    private static func screenshotEnvironment() throws -> AppEnvironment {
        let container = try ModelContainer(
            for: PersistedRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let photoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("CCScreenshotPhotos-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: photoRoot, withIntermediateDirectories: true)

        return AppEnvironment(
            recordStore: SwiftDataRecordStore(container: container),
            photoStore: FileSystemPhotoStore(rootURL: photoRoot),
            locationService: ScreenshotLocationService(),
            locationPermissionPrimerStore: InMemoryLocationPermissionPrimerStore(decision: .accepted),
            motionService: ScreenshotMotionService(),
            metadataGenerator: SystemMetadataGenerator(),
            cardPathProvider: RealCardPathProvider(),
            faceDetectionService: VisionFaceDetectionService()
        )
    }
    #endif
}
