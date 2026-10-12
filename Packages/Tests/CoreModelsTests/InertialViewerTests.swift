import Foundation
import Testing
import CoreModels

@Suite struct InertialViewerTests {
    @Test func calibrationAndStationaryPhonePreserveEye() {
        var model = InertialViewer()
        #expect(model.estimate(orientation: .identity) == nil)
        let eye = ViewerPosition(x: 0.02, y: -0.01, distance: 0.4)
        model.calibrate(eye: eye, orientation: .identity)
        let result = model.estimate(orientation: .identity)!
        #expect(abs(result.x - eye.x) < 1e-9)
        #expect(abs(result.distance - eye.distance) < 1e-9)
    }

    @Test func phoneYawMovesStationaryViewerInOppositeDirection() {
        var model = InertialViewer()
        model.calibrate(eye: ViewerPosition(x: 0, y: 0, distance: 0.4), orientation: .identity)
        let angle = Double.pi / 6
        let orientation = Quaternion(x: 0, y: sin(angle / 2), z: 0, w: cos(angle / 2))
        let result = model.estimate(orientation: orientation)!
        #expect(abs(result.x + 0.4 * sin(angle)) < 1e-9)
        #expect(abs(result.distance - 0.4 * cos(angle)) < 1e-9)
        // Reacquisition replaces the inferred world position with the measured one.
        model.calibrate(eye: result, orientation: orientation)
        let rejoined = model.estimate(orientation: orientation)!
        #expect(abs(rejoined.x - result.x) < 1e-9)
    }

    @Test func invalidAndBehindScreenPredictionsAreRejected() {
        var model = InertialViewer()
        model.calibrate(eye: ViewerPosition(x: 0, y: 0, distance: 0.4), orientation: .identity)
        #expect(model.estimate(orientation: Quaternion(x: .nan, y: 0, z: 0, w: 1)) == nil)
        #expect(model.estimate(orientation: Quaternion(x: 0, y: 1, z: 0, w: 0)) == nil)
    }
    @Test func sparseCameraUpdatesAndDropoutKeepOneContinuousTrajectory() {
        var model = InertialViewer()
        model.calibrate(eye: ViewerPosition(x: 0, y: 0, distance: 0.4), orientation: .identity)
        var previousX = 0.0
        for frame in 1...60 {
            let angle = Double(frame) * Double.pi / 180
            let orientation = Quaternion(x: 0, y: sin(angle / 2), z: 0, w: cos(angle / 2))
            let expected = ViewerPosition(x: -0.4 * sin(angle), y: 0, distance: 0.4 * cos(angle))
            // Camera delivers at 20 Hz, then loses the face for 30 ticks.
            if frame <= 30 && frame.isMultiple(of: 3) {
                model.calibrate(eye: expected, orientation: orientation)
            }
            let result = model.estimate(orientation: orientation)!
            #expect(abs(result.x - expected.x) < 1e-9)
            #expect(abs(result.distance - expected.distance) < 1e-9)
            #expect(result.x < previousX)
            #expect(abs(result.x - previousX) < 0.008)
            previousX = result.x
        }
    }

}
