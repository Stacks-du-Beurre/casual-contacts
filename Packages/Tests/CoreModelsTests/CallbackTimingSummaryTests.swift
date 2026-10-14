import Testing
@testable import CoreModels

@Suite struct CallbackTimingSummaryTests {
    @Test func emptyAndInvalidSamplesAreSafe() {
        let result = CallbackTimingSummary(intervalsMS: [.nan, .infinity, -1])
        #expect(result.count == 0)
        #expect(result.medianMS == 0)
        #expect(result.maximumMS == 0)
    }
    @Test func summarizesStallsWithoutClaimingRenderedFPS() {
        let result = CallbackTimingSummary(intervalsMS: [16, 16, 20, 40, 120, 200])
        #expect(result.medianMS == 30)
        #expect(result.p95MS == 120)
        #expect(result.maximumMS == 200)
        #expect(result.over33MS == 3)
        #expect(result.over100MS == 2)
    }
}
