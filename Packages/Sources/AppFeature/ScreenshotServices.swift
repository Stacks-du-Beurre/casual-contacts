import Foundation
import CoreModels

/// Zero motion for normal screenshot captures. The debug performance harness
/// can instead emit a repeatable waveform with a 120 Hz source and 60 Hz pose publications to exercise live card redraws.
final class ScreenshotMotionService: MotionService, @unchecked Sendable {

    private let lock = NSLock()
    private var motionTask: Task<Void, Never>?
    private var attitudeContinuation: AsyncStream<DeviceAttitude>.Continuation?
    let attitude: AsyncStream<DeviceAttitude>

    /// Screenshot mode never wants motion; the debug stream is also a no-op
    /// to keep the conformance trivial.
    let debugSamples: AsyncStream<MotionDebugSample>
    private var debugContinuation: AsyncStream<MotionDebugSample>.Continuation?

    init() {
        var attitudeContinuation: AsyncStream<DeviceAttitude>.Continuation!
        // A renderer needs the newest pose, not a backlog of stale poses
        // accumulated while a transition is busy.
        self.attitude = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { attitudeContinuation = $0 }
        self.attitudeContinuation = attitudeContinuation

        var debugContinuation: AsyncStream<MotionDebugSample>.Continuation!
        self.debugSamples = AsyncStream { debugContinuation = $0 }
        self.debugContinuation = debugContinuation
    }

    func start() {
        #if DEBUG
        if ScreenshotMode.isEnabled && ProcessInfo.processInfo.arguments.contains("-MotionPerformanceHarness") {
            lock.withLock {
                guard motionTask == nil else { return }
                let continuation = attitudeContinuation
                let unthrottled = ProcessInfo.processInfo.arguments.contains("-MotionHarnessUnthrottled")
                motionTask = Task.detached {
                    let began = ContinuousClock.now
                    var cadence = SceneUpdateCadence()
                    while !Task.isCancelled {
                        let elapsed = began.duration(to: .now)
                        let t = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
                        if unthrottled || cadence.accepts(t) {
                            continuation?.yield(DeviceAttitude(pitch: sin(t * 1.7) * 0.65,
                                                               roll: cos(t * 1.3) * 0.75))
                        }
                        do { try await Task.sleep(for: .microseconds(8333)) }
                        catch { break }
                    }
                }
            }
            return
        }
        #endif
        attitudeContinuation?.yield(.zero)
    }

    func resetZeroPoint() {
        attitudeContinuation?.yield(.zero)
    }

    func stop() {
        #if DEBUG
        if ScreenshotMode.isEnabled && ProcessInfo.processInfo.arguments.contains("-MotionPerformanceHarness") {
            lock.withLock { motionTask?.cancel(); motionTask = nil }
            return
        }
        #endif
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
