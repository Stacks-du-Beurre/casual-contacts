import Testing
import CoreModels
@testable import Services

@Suite struct GyroOrientationBufferTests {
    #if os(iOS)
    @Test @MainActor func motionCallbackCanRunOffMainExecutor() async {
        let buffer = GyroOrientationBuffer()
        let handler = buffer.motionHandler(generation: buffer.reset())
        // Even when obtained by a MainActor caller, the real callback must not
        // inherit that executor. A nil sensor packet exercises its entry check.
        await Task.detached { handler(nil, nil) }.value
        #expect(buffer.takeLatest().count == 0)
    }
    #endif
    @Test func newestSampleSurvivesWithoutMainThreadConsumption() {
        let buffer = GyroOrientationBuffer()
        let generation = buffer.reset()
        for i in 0..<180 {
            buffer.append(.init(time: Double(i), value: .identity), generation: generation, deliveredAt: Double(i) + 0.01)
        }
        let delivery = buffer.takeLatest()
        #expect(delivery.latest?.time == 179)
        #expect(delivery.count == 180)
        #expect(buffer.nearest(to: 0)?.time == 60)
        #expect(buffer.takeLatest().count == 0)
    }
    @Test func oldSessionAndOutOfOrderSamplesAreIgnored() {
        let buffer = GyroOrientationBuffer()
        let old = buffer.reset()
        let current = buffer.reset()
        buffer.append(.init(time: 10, value: .identity), generation: old, deliveredAt: 10)
        #expect(buffer.takeLatest().latest == nil)
        buffer.append(.init(time: 20, value: .identity), generation: current, deliveredAt: 20)
        buffer.append(.init(time: 19, value: .identity), generation: current, deliveredAt: 21)
        #expect(buffer.takeLatest().latest?.time == 20)
    }
}
