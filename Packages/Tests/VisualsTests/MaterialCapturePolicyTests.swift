import Testing
@testable import Visuals

struct MaterialCapturePolicyTests {
    @Test func missingSampleCanPrepareDuringInteraction() {
        #expect(MaterialCapturePolicy.delayMilliseconds(active: true, suspended: false,
                    paused: true, hasImage: false) == 32)
        #expect(MaterialCapturePolicy.delayMilliseconds(active: true, suspended: false,
                    paused: true, hasImage: true) == nil)
    }

    @Test func coveredOrInactiveCardsDoNotCapture() {
        for paused in [false, true] {
            for hasImage in [false, true] {
                #expect(MaterialCapturePolicy.delayMilliseconds(active: false, suspended: false,
                            paused: paused, hasImage: hasImage) == nil)
                #expect(MaterialCapturePolicy.delayMilliseconds(active: true, suspended: true,
                            paused: paused, hasImage: hasImage) == nil)
            }
        }
    }

    @Test func liveRefreshWaitsForSettlingAndLegacyControlDefersColdWork() {
        #expect(MaterialCapturePolicy.delayMilliseconds(active: true, suspended: false,
                    paused: false, hasImage: true) == 500)
        #expect(MaterialCapturePolicy.delayMilliseconds(active: true, suspended: false,
                    paused: true, hasImage: false, deferMissing: true) == nil)
    }
}
