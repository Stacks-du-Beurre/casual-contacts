import Testing
import CoreModels
@testable import Services

@Suite struct CameraPoseCadenceTests {
    @Test func deliversThirtyPosesFromSixtyFrames() {
        let cadence = CameraPoseCadence()
        let accepted = (0..<60).filter { cadence.accepts(Double($0) / 60) }
        #expect(accepted.count == 30)
        #expect(accepted == Array(stride(from: 0, to: 60, by: 2)))
    }
    @Test func nativeThirtyFramesAreNotHalvedAgain() {
        let cadence = CameraPoseCadence()
        #expect((0..<30).filter { cadence.accepts(Double($0) / 30) }.count == 30)
    }
    @Test func skipsDoNotCreateCatchupBurstsAndRestartResetsClock() {
        let cadence = CameraPoseCadence()
        #expect(cadence.accepts(10))
        #expect(cadence.accepts(11))
        #expect(!cadence.accepts(11.001))
        cadence.reset()
        #expect(cadence.accepts(0))
        #expect(!cadence.accepts(.nan))
    }
    @Test func thirtyHzTargetsKeepMovingOnInterveningDisplayFrames() {
        let cadence = CameraPoseCadence()
        var smoother = DisplayAttitudeSmoother()
        var target = DeviceAttitude.zero
        var previous = 0.0
        var updates = 0
        for frame in 0..<60 {
            if cadence.accepts(Double(frame) / 60) {
                target = DeviceAttitude(pitch: 0, roll: Double(frame + 1) / 120)
                updates += 1
            }
            let displayed = smoother.step(toward: target, elapsed: 1.0 / 60)
            #expect(displayed.roll > previous)
            #expect(displayed.roll - previous < 0.02)
            previous = displayed.roll
        }
        #expect(updates == 30)
    }

}
