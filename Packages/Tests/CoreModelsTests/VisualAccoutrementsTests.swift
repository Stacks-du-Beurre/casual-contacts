import Testing
import Foundation
@testable import CoreModels

@Suite struct VisualAccoutrementsTests {

    @Test func derivationIsDeterministicAcrossCalls() {
        let record = Self.makeRecord(id: UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!, name: "Jane")
        let a = record.accoutrements
        let b = record.accoutrements
        #expect(a == b)
    }

    @Test func letterIsFirstCharacterUppercased() {
        let record = Self.makeRecord(id: UUID(), name: "jane")
        #expect(record.accoutrements.letter == "J")
    }

    @Test func letterFallsBackToAForEmptyName() {
        let record = Self.makeRecord(id: UUID(), name: "")
        #expect(record.accoutrements.letter == "A")
    }

    @Test func paletteIsDerivedFromTimeOfDay() {
        let record = Self.makeRecord(id: UUID(), name: "Jane", timeOfDay: .sunset)
        #expect(record.accoutrements.palette.timeOfDay == .sunset)
    }

    @Test func guillocheShapeIsStableForSameID() {
        let id = UUID()
        let a = Self.makeRecord(id: id, name: "A").accoutrements.guillocheShape
        let b = Self.makeRecord(id: id, name: "B").accoutrements.guillocheShape
        #expect(a == b)
    }

    private static func makeRecord(id: UUID, name: String, timeOfDay: TimeOfDay = .midday) -> Record {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        return Record(
            id: id,
            name: name,
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: nil,
            createdAt: date,
            updatedAt: date,
            metadata: RecordMetadata(timeOfDay: timeOfDay, moonPhase: .fullMoon)
        )
    }
}
