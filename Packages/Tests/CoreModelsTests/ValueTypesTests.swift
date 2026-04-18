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
}
