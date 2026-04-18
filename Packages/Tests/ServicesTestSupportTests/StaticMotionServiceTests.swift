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
}
