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
    static func testing() -> AppEnvironment {
        AppEnvironment(
            recordStore: InMemoryRecordStore(),
            photoStore: InMemoryPhotoStore(),
            locationService: MockLocationService(),
            motionService: StaticMotionService(),
            metadataGenerator: FixedMetadataGenerator(),
            cardPathProvider: NoopCardPathProvider()
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
