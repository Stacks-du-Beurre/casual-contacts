import Foundation
import CoreModels

final class ScreenshotMotionService: MotionService, @unchecked Sendable {

    private var attitudeContinuation: AsyncStream<DeviceAttitude>.Continuation?
    let attitude: AsyncStream<DeviceAttitude>

    /// Screenshot mode never wants motion; the debug stream is also a no-op
    /// to keep the conformance trivial.
    let debugSamples: AsyncStream<MotionDebugSample>
    private var debugContinuation: AsyncStream<MotionDebugSample>.Continuation?

    init() {
        var attitudeContinuation: AsyncStream<DeviceAttitude>.Continuation!
        self.attitude = AsyncStream { attitudeContinuation = $0 }
        self.attitudeContinuation = attitudeContinuation

        var debugContinuation: AsyncStream<MotionDebugSample>.Continuation!
        self.debugSamples = AsyncStream { debugContinuation = $0 }
        self.debugContinuation = debugContinuation
    }

    func start() {
        attitudeContinuation?.yield(.zero)
    }

    func stop() {
        attitudeContinuation?.finish()
        attitudeContinuation = nil
        debugContinuation?.finish()
        debugContinuation = nil
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
