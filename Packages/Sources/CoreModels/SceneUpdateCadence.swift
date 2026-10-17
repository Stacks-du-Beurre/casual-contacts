import Foundation

/// Publish at 60 Hz without limiting the display link's ProMotion request.
/// Late callbacks consume the newest pose; they never replay queued updates.
public struct SceneUpdateCadence: Sendable {
    private var nextTime: Double?
    public init() {}

    public mutating func accepts(_ timestamp: Double) -> Bool {
        guard timestamp.isFinite else { return false }
        let interval = 1.0 / 60
        guard let due = nextTime else {
            nextTime = timestamp + interval
            return true
        }
        guard timestamp + 0.0001 >= due else { return false }
        nextTime = due + max(1, floor((timestamp - due) / interval) + 1) * interval
        return true
    }
}
