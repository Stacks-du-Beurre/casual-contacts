import Testing
import CoreModels

@Suite struct WindowProjectionTests {
    let neutral = ViewerPosition(x: 0, y: 0, distance: 0.4)

    @Test func rotationTracksDeepestBlendPlaneInBothOrders() {
        #expect(CardSceneDepth.blendFraction(index: 14, count: 15, reversed: false)
                == CardSceneDepth.deepestBlendFraction)
        #expect(CardSceneDepth.blendFraction(index: 0, count: 15, reversed: true)
                == CardSceneDepth.deepestBlendFraction)
        #expect(CardSceneDepth.blendFraction(index: 0, count: 1, reversed: true)
                == 0)
    }

    @Test func nearestBlendPlaneStaysOnTheScreenInBothOrders() {
        #expect(CardSceneDepth.blendFraction(index: 0, count: 15, reversed: false) == 0)
        #expect(CardSceneDepth.blendFraction(index: 14, count: 15, reversed: true) == 0)
        #expect(CardSceneDepth.blendFraction(index: 0, count: 1, reversed: false) == 0)
        let moved = ViewerPosition(x: 0.08, y: 0.04, distance: 0.25)
        let front = WindowPlaneProjection(eye: moved, reference: neutral,
            depth: CardSceneDepth.blendFraction(index: 0, count: 15, reversed: false))!
        #expect(front.scale == 1 && front.translationX == 0 && front.translationY == 0)
    }

    @Test func screenPlaneNeverMovesAndCalibrationPreservesArtwork() {
        let moved = ViewerPosition(x: 0.03, y: 0.02, distance: 0.25)
        let glass = WindowPlaneProjection(eye: moved, reference: neutral, depth: 0)!
        #expect(glass.scale == 1 && glass.translationX == 0 && glass.translationY == 0)
        let rest = WindowPlaneProjection(eye: neutral, reference: neutral, depth: 0.06)!
        #expect(rest.scale == 1 && rest.translationX == 0 && rest.translationY == 0)
    }

    @Test func deeperPlanesMoveWithEyeAndCloserEyesIncreaseParallax() {
        let eye = ViewerPosition(x: 0.03, y: 0, distance: 0.4)
        let shallow = WindowPlaneProjection(eye: eye, reference: neutral, depth: 0.02)!
        let deep = WindowPlaneProjection(eye: eye, reference: neutral, depth: 0.08)!
        #expect(abs(shallow.translationX - 0.0014285714) < 0.0000001)
        #expect(abs(deep.translationX - 0.005) < 0.0000001)
        let closer = WindowPlaneProjection(eye: ViewerPosition(x: 0.03, y: 0, distance: 0.25),
                                           reference: neutral, depth: 0.08)!
        #expect(closer.translationX > deep.translationX)
        #expect(closer.scale < 1)
    }

    @Test func calibrationHandlesOffCenterEyesAndInvalidSamples() {
        let offCenter = ViewerPosition(x: 0.02, y: 0.065, distance: 0.4)
        let rest = WindowPlaneProjection(eye: offCenter, reference: offCenter, depth: 0.06)!
        #expect(abs(rest.translationX) < 0.0000001 && abs(rest.translationY) < 0.0000001)
        #expect(WindowPlaneProjection(eye: neutral, reference: neutral, depth: -1) == nil)
        #expect(WindowPlaneProjection(eye: neutral, reference: neutral, depth: .nan) == nil)
    }
}
