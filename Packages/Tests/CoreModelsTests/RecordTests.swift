import Testing
import Foundation
@testable import CoreModels

@Suite struct RecordTests {

    private let sampleID = UUID()
    private let sampleDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func recordIsIdentifiableByID() {
        let record = Self.makeRecord(id: sampleID)
        #expect(record.id == sampleID)
    }

    @Test func recordRoundTripsThroughJSON() throws {
        let original = Self.makeRecord(id: sampleID, zodiac: .virgo)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Record.self, from: data)
        #expect(decoded == original)
    }

    @Test func recordWithNilZodiacRoundTrips() throws {
        let original = Self.makeRecord(id: sampleID, zodiac: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Record.self, from: data)
        #expect(decoded.zodiacSign == nil)
    }

    @Test func recordDraftInitializesWithDefaults() {
        let draft = RecordDraft(name: "Jane")
        #expect(draft.name == "Jane")
        #expect(draft.description == "")
        #expect(draft.photo == nil)
        #expect(draft.location == nil)
        #expect(draft.zodiacSign == nil)
    }

    @Test func recordMetadataEqualityUsesAllFields() {
        let m1 = RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
        let m2 = RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
        let m3 = RecordMetadata(timeOfDay: .sunset, moonPhase: .newMoon)
        #expect(m1 == m2)
        #expect(m1 != m3)
    }

    private static func makeRecord(id: UUID, zodiac: ZodiacSign? = nil) -> Record {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return Record(
            id: id,
            name: "Jane",
            description: "Met at the coffee shop",
            photoID: nil,
            location: LocationInfo(latitude: 37.77, longitude: -122.41, label: "SF"),
            zodiacSign: zodiac,
            createdAt: date,
            updatedAt: date,
            metadata: RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
        )
    }
}
