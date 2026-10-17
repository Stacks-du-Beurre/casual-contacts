#if os(iOS)
import Testing
@testable import CoreModels

@Suite struct CardDisplayFrameRateTests {
    @Test func proMotionModeRequestsUpToOneTwentyHz() {
        let range = CardDisplayFrameRate.range(lowPowerMode: false, maximumRefreshHz: 120)
        #expect(range.minimum == 60)
        #expect(range.maximum == 120)
        #expect(range.preferred == 120)
    }
    @Test func standardDisplaysRemainAtSixtyHz() {
        let range = CardDisplayFrameRate.range(lowPowerMode: false, maximumRefreshHz: 60)
        #expect(range.minimum == 60)
        #expect(range.maximum == 60)
        #expect(range.preferred == 60)
    }
    @Test func lowPowerModeKeepsAdaptiveCadence() {
        let range = CardDisplayFrameRate.range(lowPowerMode: true, maximumRefreshHz: 120)
        #expect(range.minimum == 30)
        #expect(range.maximum == 60)
        #expect(range.preferred == 60)
    }
}
#endif
