import Testing
import SwiftUI
import CoreModels
@testable import Visuals

@Suite struct GuillocheBlendLayerTests {

    private func makePaths(count: Int) -> [Path] {
        (0..<count).map { _ in
            Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: 10, y: 10)) }
        }
    }

    @Test func flatAttitudeKeepsAllPathsAtSamePosition() {
        // Not easily testable directly through View body — we expose the offset helper.
        for i in 0..<15 {
            let offset = GuillocheBlendLayer.offset(forPathIndex: i, pathCount: 15, attitude: .zero)
            #expect(offset.width == 0)
            #expect(offset.height == 0)
        }
    }

    @Test func unreversedStackAnchorsLastPathFirstPathMovesMost() {
        let attitude = DeviceAttitude(pitch: 0.5, roll: 0.5)
        let firstOffset = GuillocheBlendLayer.offset(forPathIndex: 0, pathCount: 15, attitude: attitude)
        let lastOffset = GuillocheBlendLayer.offset(forPathIndex: 14, pathCount: 15, attitude: attitude)

        #expect(lastOffset.width == 0)
        #expect(lastOffset.height == 0)
        #expect(abs(firstOffset.width) > 0)
        #expect(abs(firstOffset.height) > 0)
    }

    @Test func reversedStackAnchorsFirstPathLastPathMovesMost() {
        let attitude = DeviceAttitude(pitch: 0.5, roll: 0.5)
        let firstOffset = GuillocheBlendLayer.offset(forPathIndex: 0, pathCount: 15, attitude: attitude, reversed: true)
        let lastOffset = GuillocheBlendLayer.offset(forPathIndex: 14, pathCount: 15, attitude: attitude, reversed: true)

        #expect(firstOffset.width == 0)
        #expect(firstOffset.height == 0)
        #expect(abs(lastOffset.width) > 0)
        #expect(abs(lastOffset.height) > 0)
    }

    @Test func maxDepthOffsetMatchesMostShiftedPath() {
        let attitude = DeviceAttitude(pitch: 0.3, roll: -0.4)
        let maxOffset = GuillocheBlendLayer.maxDepthOffset(pathCount: 15, attitude: attitude)
        let lastOffsetReversed = GuillocheBlendLayer.offset(forPathIndex: 14, pathCount: 15, attitude: attitude, reversed: true)
        let firstOffsetUnreversed = GuillocheBlendLayer.offset(forPathIndex: 0, pathCount: 15, attitude: attitude)

        #expect(maxOffset == lastOffsetReversed)
        #expect(maxOffset == firstOffsetUnreversed)
    }

    @Test func depthOffsetScalesLinearlyWithLayerIndex() {
        let attitude = DeviceAttitude(pitch: 0.5, roll: 0.5)
        let depthScale: CGFloat = 5.0
        let layer0 = GuillocheBlendLayer.depthOffset(layer: 0, attitude: attitude, depthScale: depthScale)
        let layer1 = GuillocheBlendLayer.depthOffset(layer: 1, attitude: attitude, depthScale: depthScale)
        let layer10 = GuillocheBlendLayer.depthOffset(layer: 10, attitude: attitude, depthScale: depthScale)

        #expect(layer0 == .zero)
        #expect(layer1.width == -CGFloat(attitude.roll) * depthScale)
        #expect(layer1.height == -CGFloat(attitude.pitch) * depthScale)
        #expect(layer10.width == -CGFloat(attitude.roll) * depthScale * 10)
        #expect(layer10.height == -CGFloat(attitude.pitch) * depthScale * 10)
    }

    @Test func depthOffsetClampsNegativeLayerToZero() {
        let attitude = DeviceAttitude(pitch: 1, roll: 1)
        let offset = GuillocheBlendLayer.depthOffset(layer: -5, attitude: attitude, depthScale: 5)
        #expect(offset == .zero)
    }

    @Test func maxDepthOffsetDelegatesToDepthOffset() {
        let attitude = DeviceAttitude(pitch: 0.2, roll: -0.3)
        let viaMax = GuillocheBlendLayer.maxDepthOffset(pathCount: 15, attitude: attitude, depthScale: 5)
        let viaDepth = GuillocheBlendLayer.depthOffset(layer: 14, attitude: attitude, depthScale: 5)
        #expect(viaMax == viaDepth)
    }

    @Test @MainActor func layerInstantiatesAtEveryDensity() {
        let paths15 = makePaths(count: 15)
        let paths7 = makePaths(count: 7)
        _ = GuillocheBlendLayer(paths: paths15, density: .cards, attitude: .zero).body
        _ = GuillocheBlendLayer(paths: paths7, density: .recommended, attitude: .zero).body
        _ = GuillocheBlendLayer(paths: paths7, density: .preview, attitude: .zero).body
    }
}
