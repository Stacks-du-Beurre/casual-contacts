import Testing
import SwiftUI
import Foundation
import CoreModels
import Visuals
import StorageTestSupport
@testable import FeatureList

/// Wall-clock budgets for `RecordsListScene` body construction at scale. Same
/// caveat as `CardViewPerformanceTests`: this measures the SwiftUI body-build
/// cost, not layout/rasterization. The scene uses a `LazyVStack` so only
/// visible rows materialize at runtime. `visibleRecords` is a computed
/// property (sort + filter runs per body eval), so this test bounds the
/// combined chrome + sort cost at list scale.
@Suite @MainActor struct RecordsListPerformanceTests {

    private struct ListPathProvider: CardPathProvider {
        func rotationPaths(for _: Character) -> [Path] { [] }
        func blendPaths(
            for _: Character,
            shape _: GuillocheShape,
            density _: CCVisuals.Guilloche.LineDensity
        ) -> [Path] { [] }
    }

    private static func seededRecords(_ count: Int) -> [Record] {
        let zodiacs = ZodiacSign.allCases
        let phases = MoonPhase.allCases
        let timeOfDays = TimeOfDay.allCases
        return (0..<count).map { i in
            Record(
                id: UUID(),
                name: "Person \(i)",
                description: "Met somewhere \(i)",
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

    private func meanDuration(iterations: Int, _ work: () -> Void) -> Double {
        precondition(iterations >= 2)
        let clock = ContinuousClock()
        var durations: [Duration] = []
        durations.reserveCapacity(iterations)
        for _ in 0..<iterations {
            let start = clock.now
            work()
            durations.append(start.duration(to: clock.now))
        }
        let measured = durations.dropFirst()
        let totalSeconds = measured.reduce(0.0) { acc, d in
            let (s, attos) = d.components
            return acc + Double(s) + Double(attos) / 1e18
        }
        return totalSeconds / Double(measured.count)
    }

    /// 50 seeded records → build the scene body 5 times, measure mean. The
    /// body itself doesn't materialize all 50 cards (LazyVStack) — it rebuilds
    /// chrome and runs the sort/filter once. Budget: ≤ 50 ms mean. A regression
    /// past 5× this points at non-trivial work creeping into list body.
    @Test func recordsListSceneBuildsWithManyRowsWithinBudget() {
        let store = InMemoryRecordStore(seed: Self.seededRecords(50))
        let provider = ListPathProvider()
        let mean = meanDuration(iterations: 5) {
            _ = RecordsListScene(
                store: store,
                paths: provider,
                attitude: .zero,
                timeOfDay: .sunset,
                onTapRecord: { _ in },
                onTapCreate: {},
                onTapSettings: {}
            ).body
        }
        #expect(mean < 0.05, "RecordsListScene body with 50 records averaged \(mean)s (budget 0.05s)")
    }
}
