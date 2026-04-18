import Testing
import Foundation
import CoreModels
@testable import AppFeature

@MainActor
@Suite struct IntegrationTests {

    @Test func endToEndCreateListDetailEditDelete() async throws {
        let env = AppEnvironment.testing()
        let metadata = env.metadataGenerator.metadata(at: Date(), location: nil)

        // Create
        let created = try await env.recordStore.create(
            RecordDraft(name: "Jane", description: "Met at cafe"),
            metadata: metadata
        )

        // List
        #expect(env.recordStore.records.count == 1)
        #expect(env.recordStore.records.first?.id == created.id)

        // Edit
        var updated = created
        updated.zodiacSign = .virgo
        try await env.recordStore.update(updated)
        #expect(env.recordStore.records.first?.zodiacSign == .virgo)

        // Delete
        try await env.recordStore.delete(id: created.id)
        #expect(env.recordStore.records.isEmpty)
    }
}
