import Testing
import Foundation
import CoreModels
import Storage
import Services
@testable import AppFeature

@MainActor
@Suite struct AppEnvironmentTests {

    #if !os(macOS)
    @Test func defaultProductionInitUsesRealServices() throws {
        let env = try AppEnvironment.production()
        // Just verify the types — we can't meaningfully assert behavior without a running app.
        #expect(env.recordStore is SwiftDataRecordStore)
        #expect(env.locationService is CoreLocationService)
        #expect(env.metadataGenerator is SystemMetadataGenerator)
    }
    #endif

    @Test func testFakeInitUsesInMemoryServices() {
        let env = AppEnvironment.testing()
        #expect(env.recordStore.records.isEmpty)
    }
}
