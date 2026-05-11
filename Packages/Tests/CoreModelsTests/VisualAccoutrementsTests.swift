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

    @Test func cyrillicLetterIsFirstCharacterUppercased() {
        let record = Self.makeRecord(id: UUID(), name: "юлия")
        #expect(record.accoutrements.letter == "Ю")
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

    @Test func guillocheShapeIsDeterministicForKnownUUID() {
        // Pinning a specific UUID → specific expected shape. If the hashing algorithm
        // ever changes, this test catches the drift and forces a deliberate update.
        let record = Self.makeRecord(
            id: UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!,
            name: "Jane"
        )
        // Compute the expected shape using the same algorithm to derive the pin value.
        // (This test will print the actual value if it fails; update the pin accordingly.)
        let shape = record.accoutrements.guillocheShape
        // Pin to whatever the byte-sum algorithm yields for this UUID.
        // Byte sum for 550E8400-E29B-41D4-A716-446655440000:
        //   0x55+0x0E+0x84+0x00+0xE2+0x9B+0x41+0xD4+0xA7+0x16+0x44+0x66+0x55+0x44+0x00+0x00 = 1401
        //   1401 % 3 = 0 → .circle  (index 0 in [.circle, .square, .polygon])
        #expect(shape == .circle)
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
