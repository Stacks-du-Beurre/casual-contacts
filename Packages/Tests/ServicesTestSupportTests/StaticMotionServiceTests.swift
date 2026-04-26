import Testing
import Foundation
import CoreModels
@testable import ServicesTestSupport

@Suite struct StaticMotionServiceTests {

    @Test func publishesSingleStaticAttitude() async {
        let service = StaticMotionService(attitude: DeviceAttitude(pitch: 0.3, roll: -0.5))
        service.start()

        var received: DeviceAttitude?
        for await value in service.attitude {
            received = value
            service.stop()
            break
        }

        #expect(received?.pitch == 0.3)
        #expect(received?.roll == -0.5)
    }

    @Test func stopEndsTheStream() async {
        let service = StaticMotionService()
        service.start()
        service.stop()

        var iterator = service.attitude.makeAsyncIterator()
        let next = await iterator.next()
        #expect(next == nil || next == DeviceAttitude.zero)
    }

    @Test func debugSamplesStreamExistsAndIsNeverYielding() async {
        let service = StaticMotionService()
        service.start()

        // Race a 50ms timeout against the debug stream — we expect the stream
        // to never yield. If the timeout wins, the test passes.
        let didYieldDebugSample = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in service.debugSamples {
                    return true
                }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(50))
                return false
            }
            // Take whichever finishes first.
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }

        #expect(didYieldDebugSample == false)
    }
}
