import Testing
@testable import CoreModels

@Suite struct SceneUpdateCadenceTests {
    @Test(arguments: [60, 120])
    func publishesSixtyPosesAtEitherDisplayRate(displayHz: Int) {
        var cadence = SceneUpdateCadence()
        let accepted = (0..<displayHz).filter { cadence.accepts(Double($0) / Double(displayHz)) }
        #expect(accepted.count == 60)
        if displayHz == 120 { #expect(accepted == Array(stride(from: 0, to: 120, by: 2))) }
    }
    @Test func slowerDisplaysDoNotLoseAnotherHalfOfTheirUpdates() {
        var cadence = SceneUpdateCadence()
        let count = (0..<30).filter { cadence.accepts(Double($0) / 30) }.count
        #expect(count == 30)
    }
    @Test func stallsDoNotReplayUpdatesAndNewSessionAcceptsImmediately() {
        var cadence = SceneUpdateCadence()
        let cases: [(Double, Bool)] = [(0, true), (1, true), (1, false), (1.001, false), (.nan, false)]
        for (time, expected) in cases {
            let accepted = cadence.accepts(time)
            #expect(accepted == expected)
        }
        cadence = SceneUpdateCadence()
        let restarted = cadence.accepts(0)
        #expect(restarted)
    }
}
