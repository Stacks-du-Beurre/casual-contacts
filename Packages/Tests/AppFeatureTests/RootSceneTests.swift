import Testing
import SwiftUI
import CoreModels
@testable import AppFeature

@MainActor
@Suite struct RootSceneTests {

    @Test func initBuildsWithTestingEnvironment() {
        let env = AppEnvironment.testing()
        let scene = RootScene(environment: env)
        // Smoke test: instantiation alone proves the types compose. We can't
        // meaningfully host a `Scene` in unit tests without XCUITest.
        _ = scene
    }

    @Test func navigationRouterDefaultsAreAllClear() {
        let router = NavigationRouter()
        #expect(router.showingCreate == false)
        #expect(router.showingSettings == false)
        #expect(router.showingAbout == false)
        #expect(router.selectedRecordForMediumDetail == nil)
        #expect(router.selectedRecordForLargeDetail == nil)
        #expect(router.editingRecord == nil)
    }

    @Test func navigationRouterStoresRecordSelection() {
        let router = NavigationRouter()
        let record = Record(
            id: UUID(),
            name: "Jane",
            description: "Met at cafe",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .newMoon)
        )
        router.selectedRecordForMediumDetail = record
        #expect(router.selectedRecordForMediumDetail?.id == record.id)
    }
}
