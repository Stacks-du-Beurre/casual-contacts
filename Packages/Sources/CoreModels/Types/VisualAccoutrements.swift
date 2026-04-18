import Foundation

public struct VisualAccoutrements: Hashable, Sendable {
    public let palette: ColorPalette
    public let letter: Character
    public let guillocheShape: GuillocheShape

    public init(palette: ColorPalette, letter: Character, guillocheShape: GuillocheShape) {
        self.palette = palette
        self.letter = letter
        self.guillocheShape = guillocheShape
    }
}

public extension Record {
    var accoutrements: VisualAccoutrements {
        let firstLetter: Character = {
            guard let c = name.first, c.isLetter else { return "A" }
            return Character(String(c).uppercased())
        }()

        // Deterministic across processes — Swift's String/Int hashValue is seeded per launch,
        // so we sum the UUID's raw bytes instead. Stable for the lifetime of a record.
        var byteSum: Int = 0
        withUnsafeBytes(of: id.uuid) { bytes in
            for byte in bytes { byteSum &+= Int(byte) }
        }
        let shapeIndex = byteSum % GuillocheShape.allCases.count
        let shape = GuillocheShape.allCases[shapeIndex]

        return VisualAccoutrements(
            palette: ColorPalette(timeOfDay: metadata.timeOfDay),
            letter: firstLetter,
            guillocheShape: shape
        )
    }
}
