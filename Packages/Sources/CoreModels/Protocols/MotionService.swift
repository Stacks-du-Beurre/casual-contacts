import Foundation

public protocol MotionService: AnyObject, Sendable {
    /// The production attitude stream. Throttled, smoothed, shaped — the value
    /// every visual consumer (CardView, etc.) reads.
    var attitude: AsyncStream<DeviceAttitude> { get }

    /// Side-channel debug stream. Yields one `MotionDebugSample` per inbound
    /// motion-sensor callback (i.e., regardless of the production-stream
    /// throttle). Carries every pipeline stage so a debug screen can show the
    /// signal at every step. Never-yielding on test/preview fakes; populated
    /// by the concrete `CoreMotionService` only in `#if DEBUG` builds. Always
    /// present on the protocol so consumers don't need conditional dispatch.
    var debugSamples: AsyncStream<MotionDebugSample> { get }

    /// Reset the current device pose as the zero point on the next available
    /// sensor sample. Implementations should emit `.zero` immediately if they
    /// can, so visuals center before the next CoreMotion callback arrives.
    func resetZeroPoint()
    func start()
    func stop()
}
