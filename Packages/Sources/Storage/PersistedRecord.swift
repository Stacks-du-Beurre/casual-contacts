import Foundation
import SwiftData

@Model
public final class PersistedRecord {
    public var id: UUID
    public var name: String
    public var recordDescription: String
    public var photoFilename: String?
    /// Normalized focus point (top-left origin, 0…1). Both components are nil
    /// for records saved before face-detection shipped, for records whose photo
    /// has no detectable face, or for records without a photo. Lightweight
    /// schema evolution: SwiftData treats the new optional columns as absent
    /// on legacy rows.
    public var photoFocusX: Double?
    public var photoFocusY: Double?
    public var latitude: Double?
    public var longitude: Double?
    public var locationLabel: String?
    public var zodiacSignRaw: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var timeOfDayRaw: String
    public var moonPhaseRaw: String
    /// Optional for lightweight schema evolution: records created before this
    /// field existed decode as `nil` and fall back to the UUID-derived default.
    public var guillocheShapeRaw: String?

    public init(
        id: UUID,
        name: String,
        recordDescription: String,
        photoFilename: String?,
        photoFocusX: Double? = nil,
        photoFocusY: Double? = nil,
        latitude: Double?,
        longitude: Double?,
        locationLabel: String?,
        zodiacSignRaw: String?,
        createdAt: Date,
        updatedAt: Date,
        timeOfDayRaw: String,
        moonPhaseRaw: String,
        guillocheShapeRaw: String? = nil
    ) {
        self.id = id
        self.name = name
        self.recordDescription = recordDescription
        self.photoFilename = photoFilename
        self.photoFocusX = photoFocusX
        self.photoFocusY = photoFocusY
        self.latitude = latitude
        self.longitude = longitude
        self.locationLabel = locationLabel
        self.zodiacSignRaw = zodiacSignRaw
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.timeOfDayRaw = timeOfDayRaw
        self.moonPhaseRaw = moonPhaseRaw
        self.guillocheShapeRaw = guillocheShapeRaw
    }
}
