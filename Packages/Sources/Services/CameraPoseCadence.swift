import Foundation

/// Limits pose extraction before it allocates a main-actor delivery task.
/// ARKit may capture faster if the device has no native 30 fps face format.
final class CameraPoseCadence: @unchecked Sendable {
    private let lock = NSLock()
    private var nextTime: Double?
    private let interval = 1.0 / 30.0

    func reset() { lock.withLock { nextTime = nil } }

    func accepts(_ timestamp: Double) -> Bool {
        lock.withLock {
            guard timestamp.isFinite else { return false }
            guard let due = nextTime else {
                nextTime = timestamp + interval
                return true
            }
            guard timestamp + 0.0001 >= due else { return false }
            nextTime = due + max(1, floor((timestamp - due) / interval) + 1) * interval
            return true
        }
    }
}
