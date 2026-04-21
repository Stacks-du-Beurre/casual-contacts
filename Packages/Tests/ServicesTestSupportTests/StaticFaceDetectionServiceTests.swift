import Testing
import Foundation
import CoreModels
@testable import ServicesTestSupport

@Suite struct StaticFaceDetectionServiceTests {

    @Test func returnsConfiguredResult() async {
        let service = StaticFaceDetectionService(result: NormalizedPoint(x: 0.3, y: 0.4))
        let result = await service.focusPoint(in: Data([0xFF]))
        #expect(result == NormalizedPoint(x: 0.3, y: 0.4))
    }

    @Test func returnsNilWhenConfigured() async {
        let service = StaticFaceDetectionService(result: nil)
        let result = await service.focusPoint(in: Data([0xFF]))
        #expect(result == nil)
    }

    @Test func incrementsCallCount() async {
        let service = StaticFaceDetectionService()
        _ = await service.focusPoint(in: Data())
        _ = await service.focusPoint(in: Data())
        #expect(service.callCount == 2)
    }

    @Test func honorsDelay() async {
        let service = StaticFaceDetectionService(result: .center, delay: .milliseconds(50))
        let start = Date()
        _ = await service.focusPoint(in: Data())
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed >= 0.04)
    }
}
