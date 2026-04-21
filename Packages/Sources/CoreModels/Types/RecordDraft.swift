import Foundation

public struct RecordDraft: Sendable {
    public var name: String
    public var description: String
    public var photo: Data?
    public var location: LocationInfo?
    public var zodiacSign: ZodiacSign?
    public var guillocheShape: GuillocheShape?

    public init(
        name: String,
        description: String = "",
        photo: Data? = nil,
        location: LocationInfo? = nil,
        zodiacSign: ZodiacSign? = nil,
        guillocheShape: GuillocheShape? = nil
    ) {
        self.name = name
        self.description = description
        self.photo = photo
        self.location = location
        self.zodiacSign = zodiacSign
        self.guillocheShape = guillocheShape
    }
}
