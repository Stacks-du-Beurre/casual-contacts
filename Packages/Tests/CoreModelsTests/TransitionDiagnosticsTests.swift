#if os(iOS)
import Foundation
import Testing
@testable import CoreModels

@MainActor @Suite struct TransitionDiagnosticsTests {
    @Test func cameraEvidenceResetsForEachTransitionAndExportsWithoutDisplayTicks() async throws {
        let diagnostics = PerformanceDiagnostics()
        diagnostics.start()
        diagnostics.beginTransition("enter", hasPhoto: true)
        diagnostics.receivedCamera(valid: true, ageSeconds: 0.012)
        diagnostics.receivedCamera(valid: false, ageSeconds: 0.2)
        diagnostics.endTransition("enter")
        diagnostics.beginTransition("exit", hasPhoto: true)
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
    }
}
#endif
