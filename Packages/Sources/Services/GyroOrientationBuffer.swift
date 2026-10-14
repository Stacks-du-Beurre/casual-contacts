import Foundation
import CoreModels
#if os(iOS)
import CoreMotion
import QuartzCore
#endif

/// Small synchronized history: sensor delivery never waits for SwiftUI work.
final class GyroOrientationBuffer: @unchecked Sendable {
    #if os(iOS)
    // Construct outside the controller's MainActor context: CoreMotion invokes
    // this callback on its operation queue, not the main executor.
    nonisolated func motionHandler(generation: Int) -> @Sendable (CMDeviceMotion?, Error?) -> Void {
        { [self] sample, _ in
            guard let sample else { return }
            let q = sample.attitude.quaternion
            append(.init(time: sample.timestamp, value: Quaternion(x: q.x, y: q.y, z: q.z, w: q.w)),
                   generation: generation, deliveredAt: CACurrentMediaTime())
        }
    }
    #endif
    struct Sample: Sendable {
        let time: Double
        let value: Quaternion
    }
    struct Delivery: Sendable {
        let latest: Sample?
        let count: Int
        let maximumAge: Double
    }
    private let lock = NSLock()
    private var generation = 0
    private var samples: [Sample] = []
    private var delivered = 0
    private var maximumAge = 0.0

    @discardableResult func reset() -> Int {
        lock.withLock {
            generation += 1
            samples = []
            delivered = 0
            maximumAge = 0
            return generation
        }
    }
    func append(_ sample: Sample, generation: Int, deliveredAt: Double) {
        lock.withLock {
            guard generation == self.generation,
                  samples.last.map({ sample.time > $0.time }) ?? true else { return }
            samples.append(sample)
            if samples.count > 120 { samples.removeFirst(samples.count - 120) }
            delivered += 1
            maximumAge = max(maximumAge, abs(deliveredAt - sample.time))
        }
    }
    func nearest(to time: Double) -> Sample? {
        lock.withLock { samples.min { abs($0.time - time) < abs($1.time - time) } }
    }
    func takeLatest() -> Delivery {
        lock.withLock {
            let result = Delivery(latest: samples.last, count: delivered, maximumAge: maximumAge)
            delivered = 0
            maximumAge = 0
            return result
        }
    }
}
