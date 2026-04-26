import Foundation
import CoreModels

/// Non-Observable holder for the debug screen's rolling sample buffer. Built
/// to be cheap on the hot path: `append(_:)` is O(1) and never triggers a
/// SwiftUI re-evaluation. The view drives redraws via `TimelineView(.animation)`
/// and pulls a `Snapshot` per refresh tick — not per sample arrival.
///
/// Pure logic, host-testable. No SwiftUI imports.
public final class MotionDebugViewModel: @unchecked Sendable {

    public struct Snapshot: Sendable {
        public let samples: [MotionDebugSample]   // oldest → newest
        public let latest: MotionDebugSample?
    }

    private let capacity: Int
    private var buffer: [MotionDebugSample] = []
    private let lock = NSLock()

    public init(capacity: Int = 600) {
        self.capacity = capacity
        buffer.reserveCapacity(capacity)
    }

    /// Append a new sample. If the buffer has reached `capacity`, the oldest
    /// sample is dropped. Thread-safe via `NSLock` because `append` is called
    /// from the AsyncStream consumer task while `snapshot` runs on the main
    /// thread for the Canvas redraw.
    public func append(_ sample: MotionDebugSample) {
        lock.lock()
        defer { lock.unlock() }
        if buffer.count == capacity {
            buffer.removeFirst()
        }
        buffer.append(sample)
    }

    /// Read-only copy for drawing. Cheap because the buffer is bounded.
    public func snapshot() -> Snapshot {
        lock.lock()
        let copy = buffer
        lock.unlock()
        return Snapshot(samples: copy, latest: copy.last)
    }

    /// Number of samples in the last 1 s where `throttledOutput != nil`.
    /// Caller passes the reference time so this is testable without
    /// `Date()`. The screen passes `Date()`.
    public func emissionRate(referenceTime: Date) -> Int {
        lock.lock()
        let copy = buffer
        lock.unlock()
        let cutoff = referenceTime.addingTimeInterval(-1.0)
        return copy.reduce(0) { count, sample in
            guard sample.throttledOutput != nil else { return count }
            return sample.timestamp >= cutoff ? count + 1 : count
        }
    }
}
