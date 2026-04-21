import Foundation

public struct Record: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var photoID: PhotoID?
    public var photoFocus: NormalizedPoint?
    public var location: LocationInfo?
    public var zodiacSign: ZodiacSign?
    public let createdAt: Date
    public var updatedAt: Date
    public let metadata: RecordMetadata
    public let guillocheShape: GuillocheShape

    public init(
        id: UUID,
        name: String,
        description: String,
        photoID: PhotoID?,
        photoFocus: NormalizedPoint? = nil,
        location: LocationInfo?,
        zodiacSign: ZodiacSign?,
        createdAt: Date,
        updatedAt: Date,
        metadata: RecordMetadata,
        guillocheShape: GuillocheShape? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.photoID = photoID
        self.photoFocus = photoFocus
        self.location = location
        self.zodiacSign = zodiacSign
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.guillocheShape = guillocheShape ?? .deterministic(for: id)
    }
}
