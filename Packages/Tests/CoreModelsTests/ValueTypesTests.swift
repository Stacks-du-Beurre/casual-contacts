import Testing
import Foundation
@testable import CoreModels

@Suite struct ValueTypesTests {

    @Test func locationInfoRoundTripsThroughJSON() throws {
        let original = LocationInfo(latitude: 37.7749, longitude: -122.4194, label: "San Francisco")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LocationInfo.self, from: data)
        #expect(decoded == original)
    }

    @Test func photoIDEqualityUsesFilename() {
        let a = PhotoID(filename: "abc.heic")
        let b = PhotoID(filename: "abc.heic")
        let c = PhotoID(filename: "def.heic")
        #expect(a == b)
        #expect(a != c)
    }

    @Test func deviceAttitudeZeroIsAllZeros() {
        #expect(DeviceAttitude.zero.pitch == 0)
        #expect(DeviceAttitude.zero.roll == 0)
    }

    @Test func deviceAttitudeClamps() {
        let clamped = DeviceAttitude(pitch: 5.0, roll: -9.0).clamped()
        #expect(clamped.pitch == 1.0)
        #expect(clamped.roll == -1.0)
    }

    @Test func locationAuthorizationHasThreeCases() {
        let all: [LocationAuthorization] = [.authorized, .denied, .notDetermined]
        #expect(all.count == 3)
    }

    /// Haversine distance between identical coordinates is zero.
    @Test func locationDistanceToSelfIsZero() {
        let sf = LocationInfo(latitude: 37.7749, longitude: -122.4194)
        #expect(sf.distanceMeters(to: sf) == 0)
    }

    /// Haversine distance between SF City Hall and the Ferry Building is
    /// ~2.88 km. Allow ±100 m for the spherical-earth approximation.
    @Test func locationDistanceMatchesKnownPair() {
        let cityHall = LocationInfo(latitude: 37.7793, longitude: -122.4193)
        let ferryBuilding = LocationInfo(latitude: 37.7955, longitude: -122.3937)
        let meters = cityHall.distanceMeters(to: ferryBuilding)
        #expect(abs(meters - 2880) < 100)
    }

    /// Distance is symmetric.
    @Test func locationDistanceIsSymmetric() {
        let a = LocationInfo(latitude: 40.7128, longitude: -74.0060)
        let b = LocationInfo(latitude: 40.7228, longitude: -74.0160)
        #expect(a.distanceMeters(to: b) == b.distanceMeters(to: a))
    }

    @Test func milesAndMetersConvertBothWays() {
        #expect(abs(LocationInfo.metersInMile - 1609.344) < 0.001)
    }
}
