import Foundation

public protocol LocationService: AnyObject, Sendable {
    func requestAuthorization() async -> LocationAuthorization
    func currentLocation() async throws -> LocationInfo?
}

public enum LocationServiceError: Error, Sendable, Equatable {
    case notAuthorized
    case unavailable
}
