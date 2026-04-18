import Foundation
import CoreLocation
import CoreModels

// MARK: - Internal protocol seam for testing

public protocol LocationManagerProtocol: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func requestLocation()
}

extension CLLocationManager: LocationManagerProtocol {}

// MARK: - Service

public final class CoreLocationService: NSObject, LocationService, CLLocationManagerDelegate, @unchecked Sendable {

    private let manager: LocationManagerProtocol
    private var authContinuation: CheckedContinuation<LocationAuthorization, Never>?
    private var locationContinuation: CheckedContinuation<LocationInfo?, Error>?

    public init(managerFactory: () -> LocationManagerProtocol = { CLLocationManager() }) {
        self.manager = managerFactory()
        super.init()
        self.manager.delegate = self
    }

    public func requestAuthorization() async -> LocationAuthorization {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            return .authorized
        #if os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
        case .authorizedWhenInUse:
            return .authorized
        #endif
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                self.authContinuation = continuation
                self.manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            return .notDetermined
        }
    }

    public func currentLocation() async throws -> LocationInfo? {
        let auth = await requestAuthorization()
        guard auth == .authorized else {
            throw LocationServiceError.notAuthorized
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            self.manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth: LocationAuthorization = {
            switch self.manager.authorizationStatus {
            case .authorizedAlways:
                return .authorized
            #if os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
            case .authorizedWhenInUse:
                return .authorized
            #endif
            case .denied, .restricted:
                return .denied
            case .notDetermined:
                return .notDetermined
            @unknown default:
                return .notDetermined
            }
        }()
        authContinuation?.resume(returning: auth)
        authContinuation = nil
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
            return
        }
        let info = LocationInfo(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            label: nil
        )
        locationContinuation?.resume(returning: info)
        locationContinuation = nil
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}
