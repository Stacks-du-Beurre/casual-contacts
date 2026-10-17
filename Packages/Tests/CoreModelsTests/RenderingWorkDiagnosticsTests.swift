import Testing
@testable import CoreModels

@Suite struct RenderingWorkDiagnosticsTests {
    @Test func cpuPercentUsesOneCoreAndRejectsInvalidDeltas() {
        let start = DiagnosticCPUReading(processSeconds: 10, mainThreadSeconds: 4)
        let end = DiagnosticCPUReading(processSeconds: 13, mainThreadSeconds: 4.5)
        let values = end.values(since: start, elapsed: 2)
        #expect(values["processCPUCorePercent"] == 150)
        #expect(values["mainThreadCPUCorePercent"] == 25)
        #expect(values["mainThreadCPUMS"] == 500)
        #expect(end.values(since: start, elapsed: 0).isEmpty)
        #expect(start.values(since: end, elapsed: 1).isEmpty)
        #expect(end.values(since: start, elapsed: .nan).isEmpty)
    }

    @Test func workBucketsAggregateAndResetWithoutContentData() {
        var work = RenderingWorkBucket()
        work.receivedBody(.card)
        work.receivedBody(.card)
        work.receivedBody(.materialSample)
        work.receivedSceneWork(seconds: 0.002)
        work.receivedSceneWork(seconds: 0.004)
        work.receivedSceneWork(seconds: .nan)
        #expect(work.values["viewBody_card"] == 2)
        #expect(work.values["viewBody_materialSample"] == 1)
        #expect(work.values["viewBody_sceneHost"] == 0)
        #expect(work.values["sceneWorkTotalMS"] == 6)
        #expect(work.values["sceneWorkMaximumMS"] == 4)
        #expect(work.values["sceneWorkCount"] == 2)
        work = RenderingWorkBucket()
        #expect(work.values.values.allSatisfy { $0 == 0 })
    }
}
