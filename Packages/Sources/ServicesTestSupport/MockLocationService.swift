import Foundation
import CoreModels

public final class MockLocationService: LocationService, @unchecked Sendable {

    private let authorization: LocationAuthorization
    private let location: LocationInfo?

    public init(
        authorization: LocationAuthorization = .authorized,
        location: LocationInfo? = LocationInfo(latitude: 37.7749, longitude: -122.4194, label: "San Francisco")
    ) {
        self.authorization = authorization
        self.location = location
    }

    public func currentAuthorization() -> LocationAuthorization {
        authorization
    }

    public func requestAuthorization() async -> LocationAuthorization {
        authorization
    }

    public func currentLocation() async throws -> LocationInfo? {
        if authorization == .denied { throw LocationServiceError.notAuthorized }
        return location
    }
}
