import Foundation

public protocol LocationService: AnyObject, Sendable {
    /// Synchronous read of the current OS-level authorization. Does NOT
    /// trigger the system permission prompt. Used by surfaces (e.g. the
    /// settings location toggle) that need to display state without
    /// disturbing the user.
    func currentAuthorization() -> LocationAuthorization
    func requestAuthorization() async -> LocationAuthorization
    func currentLocation() async throws -> LocationInfo?
}

public enum LocationServiceError: Error, Sendable, Equatable {
    case notAuthorized
    case unavailable
}
