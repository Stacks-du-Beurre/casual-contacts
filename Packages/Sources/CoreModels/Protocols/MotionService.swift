import Foundation

public protocol MotionService: AnyObject, Sendable {
    /// The production attitude stream. Throttled, smoothed, shaped — the value
    /// every visual consumer (CardView, etc.) reads.
    var attitude: AsyncStream<DeviceAttitude> { get }

    /// Side-channel debug stream. Yields one `MotionDebugSample` per inbound
    /// motion-sensor callback (i.e., regardless of the production-stream
    /// throttle). Carries every pipeline stage so a debug screen can show the
    /// signal at every step. Never-yielding on fakes / release builds where
    /// the sensor isn't wired. Always present on the protocol so consumers
    /// don't need conditional dispatch.
    var debugSamples: AsyncStream<MotionDebugSample> { get }

    func start()
    func stop()
}
