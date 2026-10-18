import Foundation
import CoreModels
import Testing
@testable import Visuals

struct MicroprintInscriptionTests {
    private func record(name: String = "Iris", place: String? = "Mission District") -> Record {
        Record(id: UUID(uuidString: "DEBC1102-0000-0000-0000-000000000001")!,
               name: name, description: "", photoID: nil,
               location: place.map { LocationInfo(latitude: 0, longitude: 0, label: $0) },
               zodiacSign: nil, createdAt: Date(timeIntervalSince1970: 0),
               updatedAt: Date(timeIntervalSince1970: 0),
               metadata: RecordMetadata(timeOfDay: .night, moonPhase: .fullMoon))
    }

    @Test func issueIdentitySurvivesEditing() {
        let original = MicroprintInscription(record: record())
        var edited = record(name: "Iris Rossi", place: "Caffe Rossi")
        edited.updatedAt = Date(timeIntervalSince1970: 500)
        let next = MicroprintInscription(record: edited)
        #expect(original.identity == next.identity)
        #expect(original.seed == next.seed)
        #expect(original.subject != next.subject)
        // Explicit UTC is independent of the device's changing local timezone.
        #expect(next.moment == "1970.01.01  ·  00:00 UTC")
    }

    @Test func missingPlaceAndUnicodeNamesProduceCleanInscriptions() {
        let value = MicroprintInscription(record: record(name: "  Олена\n  Іваненко  ", place: nil))
        #expect(value.subject == "ОЛЕНА ІВАНЕНКО")
        #expect(!value.subject.hasSuffix("·"))
        #expect(MicroprintInscription.clean(String(repeating: "ї", count: 200), limit: 64).count == 64)
    }

    @Test func identityUsesTheWholeUUID() {
        let first = record()
        let second = Record(id: UUID(uuidString: "DEBC1102-0000-0000-0000-000000000002")!,
                            name: first.name, description: "", photoID: nil, location: first.location,
                            zodiacSign: nil, createdAt: first.createdAt, updatedAt: first.updatedAt,
                            metadata: first.metadata)
        #expect(MicroprintInscription(record: first).identity != MicroprintInscription(record: second).identity)
    }
}
