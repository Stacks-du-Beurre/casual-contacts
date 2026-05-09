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

    @Test func offsetDirectionMatchesLocationPillBlurDirection() {
        let attitude = DeviceAttitude(pitch: 0.3, roll: -0.4)
        let offset = GuillocheBlendLayer.depthOffset(layer: 15, attitude: attitude, depthScale: 5)

        #expect(offset.width.sign == CGFloat(attitude.roll).sign)
        #expect(offset.height.sign == CGFloat(attitude.pitch).sign)
    }

    @Test func reversedMotionDirectionFlipsOffsetDirection() {
        let attitude = DeviceAttitude(pitch: 0.3, roll: -0.4)
        let normal = GuillocheBlendLayer.depthOffset(layer: 15, attitude: attitude, depthScale: 5)
        let reversed = GuillocheBlendLayer.depthOffset(
            layer: 15,
            attitude: attitude,
            depthScale: 5,
            reverseMotionDirection: true
        )

        #expect(reversed.width == -normal.width)
        #expect(reversed.height == -normal.height)
    }

    @Test func maxDepthOffsetCarriesReversedMotionDirection() {
        let attitude = DeviceAttitude(pitch: -0.2, roll: 0.3)
        let viaMax = GuillocheBlendLayer.maxDepthOffset(
            pathCount: 15,
            attitude: attitude,
            depthScale: 5,
            reverseMotionDirection: true
        )
        let viaDepth = GuillocheBlendLayer.depthOffset(
            layer: 14,
            attitude: attitude,
            depthScale: 5,
            maxLayer: 14,
            reverseMotionDirection: true
        )

        #expect(viaMax == viaDepth)
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

    @Test func depthOffsetUsesPerspectiveCurveBetweenAnchorAndMaxLayer() {
        let attitude = DeviceAttitude(pitch: 0.5, roll: 0.5)
        let depthScale: CGFloat = 5.0
        let layer0 = GuillocheBlendLayer.depthOffset(layer: 0, attitude: attitude, depthScale: depthScale)
        let layer5 = GuillocheBlendLayer.depthOffset(layer: 5, attitude: attitude, depthScale: depthScale)
        let layer10 = GuillocheBlendLayer.depthOffset(layer: 10, attitude: attitude, depthScale: depthScale)
        let layer15 = GuillocheBlendLayer.depthOffset(layer: 15, attitude: attitude, depthScale: depthScale)

        #expect(layer0 == .zero)
        #expect(abs(layer5.width) < CGFloat(attitude.roll) * depthScale * 5)
        #expect(abs(layer10.width) < CGFloat(attitude.roll) * depthScale * 10)
        #expect(layer15.width == CGFloat(attitude.roll) * depthScale * 15)
        #expect(layer15.height == CGFloat(attitude.pitch) * depthScale * 15)
        #expect(abs(layer10.width - layer5.width) < abs(layer15.width - layer10.width))
    }

    @Test func perspectiveAmountControlsDepthCurveWithoutChangingMaxLayer() {
        let attitude = DeviceAttitude(pitch: 0.5, roll: 0.5)
        let depthScale: CGFloat = 5.0
        let linearMid = GuillocheBlendLayer.depthOffset(
            layer: 5,
            attitude: attitude,
            depthScale: depthScale,
            perspectiveAmount: 0
        )
        let currentMid = GuillocheBlendLayer.depthOffset(
            layer: 5,
            attitude: attitude,
            depthScale: depthScale,
            perspectiveAmount: 1
        )
        let strongerMid = GuillocheBlendLayer.depthOffset(
            layer: 5,
            attitude: attitude,
            depthScale: depthScale,
            perspectiveAmount: 2
        )
        let linearMax = GuillocheBlendLayer.depthOffset(
            layer: 15,
            attitude: attitude,
            depthScale: depthScale,
            perspectiveAmount: 0
        )
        let currentMax = GuillocheBlendLayer.depthOffset(
            layer: 15,
            attitude: attitude,
            depthScale: depthScale,
            perspectiveAmount: 1
        )

        #expect(linearMid.width == CGFloat(attitude.roll) * depthScale * 5)
        #expect(abs(strongerMid.width) < abs(currentMid.width))
        #expect(abs(currentMid.width) < abs(linearMid.width))
        #expect(linearMax == currentMax)
    }

    @Test func depthOffsetClampsNegativeLayerToZero() {
        let attitude = DeviceAttitude(pitch: 1, roll: 1)
        let offset = GuillocheBlendLayer.depthOffset(layer: -5, attitude: attitude, depthScale: 5)
        #expect(offset == .zero)
    }

    @Test func reverseDepthOrderSwapsAnchoredAndMostMobileLayers() {
        let attitude = DeviceAttitude(pitch: 0.5, roll: 0.5)
        let depthScale: CGFloat = 5.0

        let layer0 = GuillocheBlendLayer.depthOffset(
            layer: 0,
            attitude: attitude,
            depthScale: depthScale,
            maxLayer: 15,
            reverseDepthOrder: true
        )
        let layer15 = GuillocheBlendLayer.depthOffset(
            layer: 15,
            attitude: attitude,
            depthScale: depthScale,
            maxLayer: 15,
            reverseDepthOrder: true
        )

        #expect(layer0.width == CGFloat(attitude.roll) * depthScale * 15)
        #expect(layer0.height == CGFloat(attitude.pitch) * depthScale * 15)
        #expect(layer15 == .zero)
    }

    @Test func maxDepthOffsetDelegatesToDepthOffset() {
        let attitude = DeviceAttitude(pitch: 0.2, roll: -0.3)
        let viaMax = GuillocheBlendLayer.maxDepthOffset(pathCount: 15, attitude: attitude, depthScale: 5)
        let viaDepth = GuillocheBlendLayer.depthOffset(layer: 14, attitude: attitude, depthScale: 5, maxLayer: 14)
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
