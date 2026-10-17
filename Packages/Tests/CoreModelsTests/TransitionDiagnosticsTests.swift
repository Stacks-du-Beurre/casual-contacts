#if os(iOS)
import Foundation
import Testing
@testable import CoreModels

@MainActor @Suite struct TransitionDiagnosticsTests {
    @Test func cameraEvidenceResetsForEachTransitionAndExportsWithoutDisplayTicks() async throws {
        let diagnostics = PerformanceDiagnostics()
        diagnostics.receivedViewBody(.card) // Recording off: must not leak into export.
        diagnostics.start()
        diagnostics.beginTransition("enter", hasPhoto: true)
        diagnostics.receivedViewBody(.card)
        diagnostics.receivedSceneWork(seconds: 0.002)
        diagnostics.receivedCamera(valid: true, ageSeconds: 0.012)
        diagnostics.receivedCamera(valid: false, ageSeconds: 0.2)
        diagnostics.endTransition("enter")
        diagnostics.beginTransition("exit", hasPhoto: true)
        diagnostics.receivedViewBody(.list)
        diagnostics.receivedSceneWork(seconds: 0.004)
        diagnostics.receivedCamera(valid: true, ageSeconds: 0.01)
        diagnostics.endTransition("exit")
        let url = try await diagnostics.export()
        let report = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let rows = try #require(report["rows"] as? [[String: Any]])
        let enter = try #require(rows.first { $0["event"] as? String == "enter_completed" }?["values"] as? [String: Double])
        let exit = try #require(rows.first { $0["event"] as? String == "exit_completed" }?["values"] as? [String: Double])
        #expect(enter["cameraFrames"] == 2)
        #expect(enter["maximumCameraAgeMS"] == 200)
        #expect(exit["cameraFrames"] == 1)
        #expect(exit["maximumCameraAgeMS"] == 10)
        #expect(exit["minimumScheduledIntervalMS"] == 0)
        #expect(exit["maximumScheduledIntervalMS"] == 0)
        #expect(enter["viewBody_card"] == 1)
        #expect(enter["viewBody_list"] == 0)
        #expect(exit["viewBody_card"] == 0)
        #expect(exit["viewBody_list"] == 1)
        #expect(enter["sceneWorkTotalMS"] == 2)
        #expect(exit["sceneWorkTotalMS"] == 4)
        #expect(try #require(enter["mainThreadCPUMS"]) >= 0)
        #expect(try #require(enter["processCPUMS"]) >= 0)
        #expect(report["schemaVersion"] as? Int == 2)
        let sample = try #require(rows.first { $0["event"] as? String == "sample" }?["values"] as? [String: Double])
        #expect(sample["viewBody_card"] == 1)
        #expect(sample["sceneWorkTotalMS"] == 6)
    }
}
#endif
