import Testing
import Foundation
import CoreModels
@testable import FeatureSettings

@Suite struct MotionDebugViewModelTests {

    private func sample(
        at t: TimeInterval,
        emitted: Bool = true,
        rawPitch: Double = 0
    ) -> MotionDebugSample {
        MotionDebugSample(
            timestamp: Date(timeIntervalSince1970: t),
            rawEulerPitch: rawPitch,
            rawEulerRoll: 0,
            rawEulerYaw: 0,
            rawQuaternion: SIMD4<Double>(0, 0, 0, 1),
            gravity: SIMD3<Double>(0, 0, -1),
            normalizedPitch: 0,
            normalizedRoll: 0,
            baseline: .zero,
            baselineRelative: .zero,
            smoothed: .zero,
            shaped: .zero,
            throttledOutput: emitted ? .zero : nil,
            secondsSinceSettleReset: 0,
            isRebaseInProgress: false,
            rebaseProgress: 0
        )
    }

    @Test func snapshotIsEmptyBeforeAnySample() {
        let viewModel = MotionDebugViewModel(capacity: 4)
        let snapshot = viewModel.snapshot()
        #expect(snapshot.samples.isEmpty)
        #expect(snapshot.latest == nil)
    }

    @Test func appendStoresLatest() {
        let viewModel = MotionDebugViewModel(capacity: 4)
        let sample = sample(at: 1, rawPitch: 0.42)
        viewModel.append(sample)
        let snapshot = viewModel.snapshot()
        #expect(snapshot.latest == sample)
        #expect(snapshot.samples.count == 1)
    }

    @Test func ringBufferDropsOldestWhenFull() {
        let viewModel = MotionDebugViewModel(capacity: 3)
        for i in 0..<5 {
            viewModel.append(sample(at: TimeInterval(i)))
        }
        let snapshot = viewModel.snapshot()
        #expect(snapshot.samples.count == 3)
        // Should be the last three (timestamps 2, 3, 4)
        #expect(snapshot.samples.first?.timestamp == Date(timeIntervalSince1970: 2))
        #expect(snapshot.samples.last?.timestamp == Date(timeIntervalSince1970: 4))
    }

    @Test func emissionRateCountsThrottledOutputsInLastSecond() {
        let viewModel = MotionDebugViewModel(capacity: 600)

        // 30 emitted samples and 30 dropped samples spaced over the last 1 s.
        // Hz should report 30 (we count emitted only).
        let now = Date(timeIntervalSince1970: 100)
        for i in 0..<60 {
            let t = now.addingTimeInterval(-1.0 + Double(i) * (1.0 / 60.0))
            let emitted = i % 2 == 0
            viewModel.append(sample(at: t.timeIntervalSince1970, emitted: emitted))
        }

        // One sample exactly at `now` to anchor the window.
        viewModel.append(sample(at: now.timeIntervalSince1970, emitted: true))

        #expect(viewModel.emissionRate(referenceTime: now) >= 28)
        #expect(viewModel.emissionRate(referenceTime: now) <= 32)
    }

    @Test func emissionRateIgnoresSamplesOlderThanOneSecond() {
        let viewModel = MotionDebugViewModel(capacity: 600)
        let now = Date(timeIntervalSince1970: 100)

        // Old sample 5 seconds ago — must be ignored.
        viewModel.append(sample(at: now.addingTimeInterval(-5).timeIntervalSince1970, emitted: true))
        // Fresh sample at now.
        viewModel.append(sample(at: now.timeIntervalSince1970, emitted: true))

        #expect(viewModel.emissionRate(referenceTime: now) == 1)
    }
}
