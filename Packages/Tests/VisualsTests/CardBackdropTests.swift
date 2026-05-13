import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import Visuals

@MainActor
@Suite struct CardBackdropTests {

    private struct StubPaths: CardPathProvider {
        func rotationPaths(for letter: Character) -> [Path] { [] }
        func blendPaths(for letter: Character, shape: GuillocheShape, density: CCVisuals.Guilloche.LineDensity) -> [Path] { [] }
    }

    private func record() -> Record {
        Record(
            id: UUID(),
            name: "Jane",
            description: "",
            photoID: nil,
            location: nil,
            zodiacSign: .virgo,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)
        )
    }

    @Test func backdropInstantiatesWithoutPhoto() {
        _ = CardBackdrop(
            record: record(),
            attitude: .zero,
            paths: StubPaths(),
            photo: nil
        ).body
    }

    @Test func backdropInstantiatesWithPhoto() {
        _ = CardBackdrop(
            record: record(),
            attitude: .zero,
            paths: StubPaths(),
            photo: Image(systemName: "photo")
        ).body
    }

    @Test func rotationGuillocheUsageSeparatesPhotoCards() {
        #expect(CardBackdrop.rotationGuillocheUsage(hasPhoto: false) == .card)
        #expect(CardBackdrop.rotationGuillocheUsage(hasPhoto: true) == .cardPhoto)
    }

    @Test func photoParallaxOffsetUsesLayerSixteenDepth() {
        let attitude = DeviceAttitude(pitch: 0.25, roll: -0.5)
        let offset = CardBackdrop.photoParallaxOffset(
            attitude: attitude,
            depthScale: 5,
            reverseDepthOrder: false,
            reverseMotionDirection: false,
            movementScaleX: 0.8,
            movementScaleY: 0.7,
            perspectiveAmount: 1
        )
        let expected = GuillocheBlendLayer.maxDepthOffset(
            pathCount: 17,
            attitude: attitude,
            depthScale: 5,
            reverseDepthOrder: false,
            reverseMotionDirection: false,
            movementScaleX: 0.8,
            movementScaleY: 0.7,
            perspectiveAmount: 1
        )

        #expect(offset == expected)
    }

    @Test func photoParallaxOffsetKeepsMaxMotionWhenDepthOrderIsReversed() {
        let attitude = DeviceAttitude(pitch: 0.25, roll: -0.5)
        let offset = CardBackdrop.photoParallaxOffset(
            attitude: attitude,
            depthScale: 5,
            reverseDepthOrder: true,
            reverseMotionDirection: false,
            movementScaleX: 0.8,
            movementScaleY: 0.7,
            perspectiveAmount: 1
        )
        let expected = GuillocheBlendLayer.maxDepthOffset(
            pathCount: 17,
            attitude: attitude,
            depthScale: 5,
            reverseDepthOrder: true,
            reverseMotionDirection: false,
            movementScaleX: 0.8,
            movementScaleY: 0.7,
            perspectiveAmount: 1
        )

        #expect(offset == expected)
        #expect(offset != .zero)
    }

    @Test func photoParallaxOverscanUsesFullLayerSixteenBudget() {
        let overscan = CardBackdrop.photoParallaxOverscan(
            depthScale: 5,
            reverseDepthOrder: false,
            reverseMotionDirection: true,
            movementScaleX: 0.8,
            movementScaleY: 0.7,
            perspectiveAmount: 1
        )
        let maxOffset = CardBackdrop.photoParallaxOffset(
            attitude: DeviceAttitude(pitch: 1, roll: 1),
            depthScale: 5,
            reverseDepthOrder: false,
            reverseMotionDirection: true,
            movementScaleX: 0.8,
            movementScaleY: 0.7,
            perspectiveAmount: 1
        )

        #expect(overscan == CGSize(width: abs(maxOffset.width), height: abs(maxOffset.height)))
    }
}
