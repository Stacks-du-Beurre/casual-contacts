import Foundation
import CoreModels

/// Always-zero `MotionService` for screenshot generation. Yields exactly one
/// `.zero` attitude when started, then ignores subsequent `start()` /
/// `stop()` calls. Cards painted with this service show no tilt or
/// parallax — the captured frame is identical across runs.
final class ScreenshotMotionService: MotionService, @unchecked Sendable {

    private var continuation: AsyncStream<DeviceAttitude>.Continuation?
    let attitude: AsyncStream<DeviceAttitude>

    init() {
        var continuation: AsyncStream<DeviceAttitude>.Continuation!
        self.attitude = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    func start() {
        continuation?.yield(.zero)
    }

    func stop() {
        continuation?.finish()
        continuation = nil
    }
}

/// Returns a fixed San Francisco origin so the distance-sort proximity
/// grouping renders deterministically: two seed records (`Iris`, `Dashiell`)
/// fall inside the 1-mile radius and four sit clearly farther.
final class ScreenshotLocationService: LocationService, @unchecked Sendable {

    /// SF coordinates the seeded records' distances are computed against.
    /// Matches `MockLocationService`'s default so any test that already
    /// happens to share the radius math behaves the same here.
    static let origin = LocationInfo(
        latitude: 37.7749,
        longitude: -122.4194,
        label: "San Francisco"
    )

    func currentAuthorization() -> LocationAuthorization {
        .authorized
    }

    func requestAuthorization() async -> LocationAuthorization {
        .authorized
    }

    func currentLocation() async throws -> LocationInfo? {
        Self.origin
    }
}
