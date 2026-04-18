#if canImport(UIKit)
import Testing
import SwiftUI
import UIKit
import SnapshotTesting
import Foundation
import CoreModels
@testable import Visuals

@Suite @MainActor struct DynamicTypeSnapshotTests {

    private func makeRecord() -> Record {
        Record(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Jane Elizabeth",
            description: "Met at the coffee shop on a rainy Tuesday",
            photoID: nil,
            location: LocationInfo(latitude: 37.77, longitude: -122.41, label: "1200 TREAT AVE"),
            zodiacSign: .virgo,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            metadata: RecordMetadata(timeOfDay: .sunset, moonPhase: .fullMoon)
        )
    }

    @Test func mediumCardAtAccessibilityXXXL() {
        let view = CardView(
            record: makeRecord(),
            size: .medium,
            attitude: .zero,
            paths: StubCardPathProvider()
        )
        .environment(\.dynamicTypeSize, .accessibility5)

        let controller = UIHostingController(rootView: view.frame(width: 335, height: 211).background(.black))
        assertSnapshot(of: controller, as: .image(size: CGSize(width: 335, height: 211)))
    }

    @Test func largeCardAtAccessibilityXXXL() {
        let view = CardView(
            record: makeRecord(),
            size: .large,
            attitude: .zero,
            paths: StubCardPathProvider()
        )
        .environment(\.dynamicTypeSize, .accessibility5)

        let controller = UIHostingController(rootView: view.frame(width: 375, height: 600).background(.black))
        assertSnapshot(of: controller, as: .image(size: CGSize(width: 375, height: 600)))
    }
}
#endif
