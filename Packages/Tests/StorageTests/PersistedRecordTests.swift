import Testing
import Foundation
import SwiftData
@testable import Storage

@Suite struct PersistedRecordTests {

    @Test func canInsertAndFetchPersistedRecord() throws {
        let container = try ModelContainer(
            for: PersistedRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let record = PersistedRecord(
            id: UUID(),
            name: "Jane",
            recordDescription: "Met at the coffee shop",
            photoFilename: nil,
            latitude: nil,
            longitude: nil,
            locationLabel: nil,
            zodiacSignRaw: nil,
            createdAt: Date(),
            updatedAt: Date(),
            timeOfDayRaw: "sunset",
            moonPhaseRaw: "fullMoon"
        )
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PersistedRecord>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Jane")
    }
}
