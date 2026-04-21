import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import Visuals

/// Wall-clock performance budgets for the per-gyro-sample work inside
/// attitude-reactive card surfaces. We can't measure SwiftUI layout/rasterize
/// from unit tests, but we can measure `body` construction cost and pure-math
/// helpers that run on every gyro sample. Budgets are generous enough to pass
/// on CI macs under load and catch 5–10× regressions.
///
/// Sample stream: 60 evenly-spaced points tracing a sinusoid in
/// (pitch, roll) ∈ ±1, mirroring one second of motion at 60 Hz. A fixed
/// seed-equivalent (deterministic math) keeps runs comparable.
@Suite struct CardViewPerformanceTests {

    // MARK: - Attitude stream

    /// 60 samples along (pitch, roll) = (sin(2πt), cos(2πt)), t ∈ [0, 1).
    /// Covers the full ±1 range each axis hits in real use.
    static let attitudeStream: [DeviceAttitude] = (0..<60).map { i in
        let t = Double(i) / 60.0
        let angle = 2.0 * .pi * t
        return DeviceAttitude(pitch: sin(angle), roll: cos(angle))
    }

    // MARK: - Helpers

    private func sampleRecord(zodiac: ZodiacSign? = .leo) -> Record {
        Record(
            id: UUID(),
            name: "Alona",
            description: "Met at Sightglass",
            photoID: nil,
            location: LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 TREAT AVE"),
            zodiacSign: zodiac,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
        )
    }

    /// Times `iterations` runs of `work`, discards the first (warm-up), and
    /// returns the mean duration of the remaining runs in seconds.
    private func meanDuration(
        iterations: Int,
        _ work: () -> Void
    ) -> Double {
        precondition(iterations >= 2, "need at least 2 iterations for warm-up + measurement")
        let clock = ContinuousClock()
        var durations: [Duration] = []
        durations.reserveCapacity(iterations)
        for _ in 0..<iterations {
            let start = clock.now
            work()
            durations.append(start.duration(to: clock.now))
        }
        // Drop warm-up.
        let measured = durations.dropFirst()
        let totalSeconds = measured.reduce(0.0) { acc, d in
            let (seconds, attos) = d.components
            return acc + Double(seconds) + Double(attos) / 1e18
        }
        return totalSeconds / Double(measured.count)
    }

    // MARK: - CardView body build

    /// Rebuilds `CardView.body` once per attitude sample (60 samples per run).
    /// Budget: mean run ≤ 250 ms. CardView's body builds the full ZStack of
    /// backdrop + ornaments + text layer; each sample triggers the whole tree
    /// because `attitude` is a stored property. A regression that makes this
    /// 5× slower points at a new per-sample cost in the body.
    @Test @MainActor func cardViewBodyUnderAttitudeStreamStaysWithinBudget() {
        let record = sampleRecord()
        let provider = StubCardPathProvider()
        let mean = meanDuration(iterations: 5) {
            for attitude in Self.attitudeStream {
                _ = CardView(
                    record: record,
                    size: .medium,
                    attitude: attitude,
                    paths: provider
                ).body
            }
        }
        #expect(mean < 0.25, "CardView body over 60 samples averaged \(mean)s (budget 0.25s)")
    }

    // MARK: - HologramText body build

    /// HologramText rebuilds its chromatic stack (offset + rotation bound to
    /// attitude) on every body evaluation. Simpler than CardView, so budget is
    /// tighter — mean run ≤ 100 ms over 60 samples.
    @Test @MainActor func hologramTextBodyUnderAttitudeStreamStaysWithinBudget() {
        let mean = meanDuration(iterations: 5) {
            for attitude in Self.attitudeStream {
                _ = HologramText(
                    "Alona",
                    font: .system(size: 48),
                    attitude: attitude,
                    backdropSize: CGSize(width: 343, height: 211),
                    coordinateSpaceName: "perfTest",
                    backdrop: { Color.clear }
                ).body
            }
        }
        #expect(mean < 0.1, "HologramText body over 60 samples averaged \(mean)s (budget 0.1s)")
    }

    // MARK: - HolographicZodiac body build

    /// HolographicZodiac reads `attitude` for its texture translation + chroma
    /// split. Budget mirrors HologramText at ≤ 100 ms for 60 samples.
    @Test @MainActor func holographicZodiacBodyUnderAttitudeStreamStaysWithinBudget() {
        let mean = meanDuration(iterations: 5) {
            for attitude in Self.attitudeStream {
                _ = HolographicZodiac(sign: .leo, attitude: attitude).body
            }
        }
        #expect(mean < 0.1, "HolographicZodiac body over 60 samples averaged \(mean)s (budget 0.1s)")
    }

    // MARK: - List-scale scenarios

    /// 20 distinct records, build `CardView.body` for each at a single
    /// attitude. Mirrors "all visible cards re-evaluate on a single gyro
    /// tick". Budget: mean ≤ 100 ms over 5 iterations. Catches regressions
    /// in per-card construction cost that scale linearly with row count.
    @Test @MainActor func cardViewBodyAcrossManyRecordsStaysWithinBudget() {
        let records = Self.scrollingRecords(count: 20)
        let provider = StubCardPathProvider()
        let mean = meanDuration(iterations: 5) {
            for record in records {
                _ = CardView(
                    record: record,
                    size: .small,
                    attitude: .zero,
                    paths: provider
                ).body
            }
        }
        #expect(mean < 0.1, "20 CardView body builds averaged \(mean)s (budget 0.1s)")
    }

    /// 20 cards × 60 attitude samples = 1200 body builds. Approximates one
    /// second of motion with 20 visible cards re-evaluating per tick. Budget:
    /// mean ≤ 500 ms over 5 iterations. This is the single test most likely
    /// to catch a perf regression that only shows up at scroll-list scale.
    @Test @MainActor func scrollingListAttitudeStreamStaysWithinBudget() {
        let records = Self.scrollingRecords(count: 20)
        let provider = StubCardPathProvider()
        let mean = meanDuration(iterations: 3) {
            for attitude in Self.attitudeStream {
                for record in records {
                    _ = CardView(
                        record: record,
                        size: .small,
                        attitude: attitude,
                        paths: provider
                    ).body
                }
            }
        }
        #expect(mean < 0.5, "20 cards × 60 samples body builds averaged \(mean)s (budget 0.5s)")
    }

    /// Synthetic dataset for the list-scale scenarios. Each record varies by
    /// zodiac, time-of-day, and moon phase so per-card switch tables get
    /// exercised across the population, not the single hot record.
    private static func scrollingRecords(count: Int) -> [Record] {
        let zodiacs = ZodiacSign.allCases
        let phases = MoonPhase.allCases
        let timeOfDays = TimeOfDay.allCases
        return (0..<count).map { i in
            Record(
                id: UUID(),
                name: "Person \(i)",
                description: "Met at place \(i)",
                photoID: nil,
                location: LocationInfo(
                    latitude: 37.0 + Double(i) * 0.001,
                    longitude: -122.0,
                    label: "ADDRESS \(i)"
                ),
                zodiacSign: zodiacs[i % zodiacs.count],
                createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(i)),
                updatedAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(i)),
                metadata: RecordMetadata(
                    timeOfDay: timeOfDays[i % timeOfDays.count],
                    moonPhase: phases[i % phases.count]
                )
            )
        }
    }

    // MARK: - GradientLayer transfusion math

    /// `transfusionOpacity` is pure math called on every body evaluation of
    /// every GradientLayer on screen. Budget is extremely tight because it's
    /// just `abs(roll * sensitivity)` + clamp — mean run ≤ 1 ms for the full
    /// 60-sample stream. Catches accidental expensive work sneaking in.
    @Test func transfusionOpacityStreamIsSubMillisecond() {
        let mean = meanDuration(iterations: 10) {
            for attitude in CardViewPerformanceTests.attitudeStream {
                _ = GradientLayer.transfusionOpacity(
                    for: attitude,
                    reduceTransparency: false,
                    sensitivity: 1.0
                )
            }
        }
        #expect(mean < 0.001, "transfusionOpacity over 60 samples averaged \(mean)s (budget 0.001s)")
    }
}
