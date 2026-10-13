import Foundation
import Testing
import CoreModels
@testable import Visuals

@Suite struct CardMotionPoseTests {
    private func pose(x: Double, distance: Double) -> CardMotionPose {
        CardMotionPose(attitude: DeviceAttitude(pitch: x, roll: -x), projection:
            WindowSceneProjection(eye: ViewerPosition(x: x, y: 0, distance: distance),
                                  reference: ViewerPosition(x: 0, y: 0, distance: 0.4),
                                  backingDepthMeters: 0.06, spacing: 1, screenWidthMeters: 0.0666,
                                  viewport: CGSize(width: 400, height: 800), cardCenteredReference: true))
    }

    @Test func resumePreservesStartAndReachesLivePose() {
        let frozen = pose(x: -0.02, distance: 0.4)
        let live = pose(x: 0.04, distance: 0.2)
        #expect(frozen.interpolated(to: live, progress: 0) == frozen)
        let final = frozen.interpolated(to: live, progress: 1)
        #expect(abs(final.attitude.pitch - live.attitude.pitch) < 1e-9)
        #expect(abs(final.projection!.eye.distance - live.projection!.eye.distance) < 1e-9)
        #expect(final.projection!.cardCenteredReference)
    }

    @Test func intermediatePoseEasesBothDistanceAndLateralMotion() {
        let mid = pose(x: 0, distance: 0.4).interpolated(to: pose(x: 0.04, distance: 0.2), progress: 0.5)
        #expect(abs(mid.projection!.eye.x - 0.02) < 1e-9)
        #expect(abs(mid.projection!.eye.distance - 0.3) < 1e-9)
        #expect(abs(mid.attitude.roll + 0.02) < 1e-9)
        #expect(mid.projection!.backingDepthMeters == 0.06)
    }

    @Test func startingOrStoppingFaceModePassesThroughZeroDepth() {
        let gyro = CardMotionPose(attitude: .zero, projection: nil)
        let face = pose(x: 0.04, distance: 0.2)
        #expect(gyro.interpolated(to: face, progress: 0).projection!.backingDepthMeters == 0)
        #expect(gyro.interpolated(to: face, progress: 0.5).projection!.backingDepthMeters == 0.03)
        #expect(face.interpolated(to: gyro, progress: 0.5).projection!.backingDepthMeters == 0.03)
        #expect(face.interpolated(to: gyro, progress: 1) == gyro)
    }
}
