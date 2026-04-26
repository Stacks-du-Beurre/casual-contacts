import Foundation
import CoreModels

/// Non-Observable holder for the debug screen's rolling sample buffer. Built
/// to be cheap on the hot path: `append(_:)` is true O(1) at steady state
/// (no array shift) and never triggers a SwiftUI re-evaluation. The view
/// drives redraws via `TimelineView(.animation)` and pulls a `Snapshot` per
/// refresh tick — not per sample arrival.
///
/// Internally a fixed-size ring buffer with a head index, so the writer task
/// and the main-thread reader don't fight over an O(n) shift while the lock
/// is held. `snapshot()` materializes the ring as a flat oldest→newest array
/// for downstream rendering.
///
/// `@unchecked Sendable` because all mutable state is guarded by `lock`.
/// Pure logic, host-testable. No SwiftUI imports.
public final class MotionDebugViewModel: @unchecked Sendable {

    public struct Snapshot: Sendable {
        public let samples: [MotionDebugSample]   // oldest → newest
        public let latest: MotionDebugSample?
    }

    private let capacity: Int

    /// Storage for at most `capacity` samples. While filling, length grows
    /// from 0 to `capacity` and `head` stays at 0. Once full, length stays
    /// at `capacity` and `head` advances modulo `capacity` per append.
    private var buffer: [MotionDebugSample] = []
    private var head: Int = 0
    private let lock = NSLock()

    public init(capacity: Int = 600) {
        precondition(capacity > 0, "MotionDebugViewModel capacity must be positive")
        self.capacity = capacity
        buffer.reserveCapacity(capacity)
    }

    /// Append a new sample. Once the buffer is full, the oldest sample is
    /// overwritten in place — no array shift. O(1) at steady state.
    /// Thread-safe via `NSLock` because `append` is called from the
    /// AsyncStream consumer task while `snapshot` runs on the main thread
    /// for the Canvas redraw.
    public func append(_ sample: MotionDebugSample) {
        lock.lock()
        defer { lock.unlock() }
        if buffer.count < capacity {
            buffer.append(sample)
        } else {
            buffer[head] = sample
            head = (head + 1) % capacity
        }
    }

    /// Materialize the ring as a flat oldest→newest array for the renderer.
    /// O(n) — necessary work; the consumer iterates this anyway. The lock is
    /// held only for the duration of the array copies, never longer.
    public func snapshot() -> Snapshot {
        lock.lock()
        let result: [MotionDebugSample]
        if buffer.count < capacity {
            // Still filling; head is 0 and order is already oldest→newest.
            result = buffer
        } else {
            // Full ring: oldest is at `head`, then wrap.
            result = Array(buffer[head..<capacity]) + Array(buffer[0..<head])
        }
        lock.unlock()
        return Snapshot(samples: result, latest: result.last)
    }

    /// Number of samples in the last 1 s where `throttledOutput != nil`.
    /// Caller passes the reference time so this is testable without
    /// `Date()`. The screen passes `Date()` from `TimelineView.date`.
    public func emissionRate(referenceTime: Date) -> Int {
        let snapshot = self.snapshot().samples
        let cutoff = referenceTime.addingTimeInterval(-1.0)
        // Walk newest → oldest and break as soon as we cross the cutoff —
        // bounded scan, typically ≤ 60 iterations regardless of buffer size.
        var count = 0
        for sample in snapshot.reversed() {
            if sample.timestamp < cutoff { break }
            if sample.throttledOutput != nil { count += 1 }
        }
        return count
    }
}
