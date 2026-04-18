import Foundation
import SwiftData

@Model
public final class PersistedRecord {
    public var id: UUID
    public var name: String
    public var recordDescription: String
    public var photoFilename: String?
    public var latitude: Double?
    public var longitude: Double?
    public var locationLabel: String?
    public var zodiacSignRaw: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var timeOfDayRaw: String
    public var moonPhaseRaw: String

    public init(
        id: UUID,
        name: String,
        recordDescription: String,
        photoFilename: String?,
        latitude: Double?,
        longitude: Double?,
        locationLabel: String?,
        zodiacSignRaw: String?,
        createdAt: Date,
        updatedAt: Date,
        timeOfDayRaw: String,
        moonPhaseRaw: String
    ) {
        self.id = id
        self.name = name
        self.recordDescription = recordDescription
        self.photoFilename = photoFilename
        self.latitude = latitude
        self.longitude = longitude
        self.locationLabel = locationLabel
        self.zodiacSignRaw = zodiacSignRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.timeOfDayRaw = timeOfDayRaw
        self.moonPhaseRaw = moonPhaseRaw
    }
}
