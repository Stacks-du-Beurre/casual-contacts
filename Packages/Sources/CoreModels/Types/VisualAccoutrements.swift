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

        let shapeIndex = abs(id.uuidString.hashValue) % GuillocheShape.allCases.count
        let shape = GuillocheShape.allCases[shapeIndex]

        return VisualAccoutrements(
            palette: ColorPalette(timeOfDay: metadata.timeOfDay),
            letter: firstLetter,
            guillocheShape: shape
        )
    }
}
