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
    public let motionService: any MotionService
    public let metadataGenerator: any MetadataGenerator
    public let cardPathProvider: any CardPathProvider

    public init(
        recordStore: any RecordStore,
        photoStore: any PhotoStore,
        locationService: any LocationService,
        motionService: any MotionService,
        metadataGenerator: any MetadataGenerator,
        cardPathProvider: any CardPathProvider
    ) {
        self.recordStore = recordStore
        self.photoStore = photoStore
        self.locationService = locationService
        self.motionService = motionService
        self.metadataGenerator = metadataGenerator
        self.cardPathProvider = cardPathProvider
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
            motionService: CoreMotionService(),
            metadataGenerator: SystemMetadataGenerator(),
            cardPathProvider: RealCardPathProvider()
        )
    }
    #endif
}
