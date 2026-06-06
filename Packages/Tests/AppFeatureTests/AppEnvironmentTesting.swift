import Foundation
import SwiftUI
import CoreModels
import Visuals
import StorageTestSupport
import ServicesTestSupport
@testable import AppFeature

extension AppEnvironment {
    /// Test-only wiring: in-memory stores + mock services. Keeps tests hermetic
    /// (no SwiftData container, no CoreLocation permission prompts, no motion).
    @MainActor
    static func testing(
        recordStore: (any RecordStore)? = nil,
        photoStore: (any PhotoStore)? = nil,
        locationService: (any LocationService)? = nil,
        locationPermissionPrimerStore: (any LocationPermissionPrimerStore)? = nil,
        listSortPreferenceStore: (any ListSortPreferenceStore)? = nil,
        lastLocationStore: (any LastLocationStore)? = nil
    ) -> AppEnvironment {
        AppEnvironment(
            recordStore: recordStore ?? InMemoryRecordStore(),
            photoStore: photoStore ?? InMemoryPhotoStore(),
            locationService: locationService ?? MockLocationService(),
            locationPermissionPrimerStore: locationPermissionPrimerStore ?? InMemoryLocationPermissionPrimerStore(),
            listSortPreferenceStore: listSortPreferenceStore ?? InMemoryListSortPreferenceStore(),
            lastLocationStore: lastLocationStore ?? InMemoryLastLocationStore(),
            motionService: StaticMotionService(),
            metadataGenerator: FixedMetadataGenerator(),
            cardPathProvider: NoopCardPathProvider(),
            faceDetectionService: StaticFaceDetectionService(result: nil)
        )
    }
}

/// Returns empty path arrays for every lookup. Lets tests construct an
/// `AppEnvironment` without pulling in the generated guilloche catalog.
struct NoopCardPathProvider: CardPathProvider {
    func rotationPaths(for letter: Character) -> [Path] { [] }
    func blendPaths(
        for letter: Character,
        shape: GuillocheShape,
        density: CCVisuals.Guilloche.LineDensity
    ) -> [Path] { [] }
}
