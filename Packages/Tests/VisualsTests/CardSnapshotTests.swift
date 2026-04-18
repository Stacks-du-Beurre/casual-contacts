#if canImport(UIKit)
import Testing
import SwiftUI
import UIKit
import SnapshotTesting
import Foundation
import CoreModels
@testable import Visuals

@Suite @MainActor struct CardSnapshotTests {

    private func makeRecord(
        id: UUID = UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!,
        timeOfDay: TimeOfDay = .sunset,
        moonPhase: MoonPhase = .fullMoon,
        zodiac: ZodiacSign? = .virgo,
        name: String = "Jane"
    ) -> Record {
        Record(
            id: id,
            name: name,
            description: "Met at the coffee shop",
            photoID: nil,
            location: LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 TREAT AVE, SAN FRANCISCO"),
            zodiacSign: zodiac,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            metadata: RecordMetadata(timeOfDay: timeOfDay, moonPhase: moonPhase)
        )
    }

    @Test func mediumCardSunsetFullMoon() {
        let view = CardView(
            record: makeRecord(),
            size: .medium,
            attitude: .zero,
            paths: StubCardPathProvider()
        )
        let controller = UIHostingController(rootView: view.frame(width: 335, height: 211).background(.black))
        assertSnapshot(of: controller, as: .image(size: CGSize(width: 335, height: 211)))
    }

    @Test func largeCardNightFullMoon() {
        let view = CardView(
            record: makeRecord(timeOfDay: .night, moonPhase: .fullMoon, zodiac: nil),
            size: .large,
            attitude: .zero,
            paths: StubCardPathProvider()
        )
        let controller = UIHostingController(rootView: view.frame(width: 375, height: 600).background(.black))
        assertSnapshot(of: controller, as: .image(size: CGSize(width: 375, height: 600)))
    }

    @Test func smallCardMiddayNewMoon() {
        let view = CardView(
            record: makeRecord(timeOfDay: .midday, moonPhase: .newMoon, zodiac: .aries),
            size: .small,
            attitude: .zero,
            paths: StubCardPathProvider()
        )
        let controller = UIHostingController(rootView: view.frame(width: 335, height: 120).background(.black))
        assertSnapshot(of: controller, as: .image(size: CGSize(width: 335, height: 120)))
    }

    @Test func mediumCardTiltedAttitude() {
        let view = CardView(
            record: makeRecord(),
            size: .medium,
            attitude: DeviceAttitude(pitch: 0.3, roll: -0.5),
            paths: StubCardPathProvider()
        )
        let controller = UIHostingController(rootView: view.frame(width: 335, height: 211).background(.black))
        assertSnapshot(of: controller, as: .image(size: CGSize(width: 335, height: 211)))
    }
}
#endif
