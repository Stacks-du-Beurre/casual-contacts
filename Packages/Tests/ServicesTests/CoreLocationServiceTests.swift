import Testing
import Foundation
import CoreLocation
import CoreModels
@testable import Services

@Suite struct CoreLocationServiceTests {

    @Test func requestAuthorizationReturnsAuthorizedWhenManagerGrants() async {
        let manager = FakeLocationManager()
        manager.nextAuthorizationStatus = .authorizedAlways

        let service = CoreLocationService(managerFactory: { manager })
        let result = await service.requestAuthorization()

        #expect(result == .authorized)
    }

    @Test func requestAuthorizationReturnsDeniedWhenManagerDenies() async {
        let manager = FakeLocationManager()
        manager.nextAuthorizationStatus = .denied

        let service = CoreLocationService(managerFactory: { manager })
        let result = await service.requestAuthorization()

        #expect(result == .denied)
    }

    @Test func currentLocationThrowsWhenNotAuthorized() async {
        let manager = FakeLocationManager()
        manager.nextAuthorizationStatus = .denied

        let service = CoreLocationService(managerFactory: { manager })
        await #expect(throws: LocationServiceError.notAuthorized) {
            _ = try await service.currentLocation()
        }
    }

    @Test func currentLocationReturnsLatestLocation() async throws {
        let manager = FakeLocationManager()
        manager.nextAuthorizationStatus = .authorizedAlways
        manager.locationToDeliver = CLLocation(latitude: 37.77, longitude: -122.41)

        let service = CoreLocationService(managerFactory: { manager })
        let result = try await service.currentLocation()

        #expect(result?.latitude == 37.77)
        #expect(result?.longitude == -122.41)
    }
}

final class FakeLocationManager: LocationManagerProtocol, @unchecked Sendable {
    weak var delegate: CLLocationManagerDelegate?
    var nextAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var locationToDeliver: CLLocation?

    var authorizationStatus: CLAuthorizationStatus { nextAuthorizationStatus }

    func requestWhenInUseAuthorization() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.locationManagerDidChangeAuthorization?(CLLocationManager())
        }
    }

    func requestLocation() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let loc = self.locationToDeliver else { return }
            self.delegate?.locationManager?(CLLocationManager(), didUpdateLocations: [loc])
        }
    }
}
