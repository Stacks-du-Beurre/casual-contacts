import Foundation

public struct LocationInfo: Hashable, Codable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let label: String?

    public init(latitude: Double, longitude: Double, label: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.label = label
    }

    /// Standard mile in meters — used by the 1-mile bucket in distance sort.
    public static let metersInMile: Double = 1609.344

    /// Great-circle distance in meters between two coordinates, computed via
    /// the haversine formula on a 6,371,000 m mean-Earth-radius sphere. Pure
    /// math so this stays out of CoreLocation; within a ~1 mi window the
    /// spherical approximation matches `CLLocation.distance(from:)` to well
    /// under a meter.
    public func distanceMeters(to other: LocationInfo) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }
}
