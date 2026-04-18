import Testing
import Foundation
import CoreModels
@testable import ServicesTestSupport

@Suite struct MockLocationServiceTests {

    @Test func returnsConfiguredAuthorization() async {
        let service = MockLocationService(authorization: .denied)
        let result = await service.requestAuthorization()
        #expect(result == .denied)
    }

    @Test func returnsConfiguredLocation() async throws {
        let location = LocationInfo(latitude: 37.77, longitude: -122.41, label: "SF")
        let service = MockLocationService(authorization: .authorized, location: location)
        let result = try await service.currentLocation()
        #expect(result == location)
    }

    @Test func currentLocationThrowsWhenNotAuthorized() async {
        let service = MockLocationService(authorization: .denied, location: nil)
        await #expect(throws: LocationServiceError.notAuthorized) {
            _ = try await service.currentLocation()
        }
    }
}
