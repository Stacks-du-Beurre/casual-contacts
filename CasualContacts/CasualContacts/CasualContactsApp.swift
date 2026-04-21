import SwiftUI
import AppFeature
import Services

@main
struct CasualContactsApp: App {
    @MainActor
    static let environment: AppEnvironment = {
        do {
            return try AppEnvironment.productionOrUITestReset()
        } catch {
            fatalError("Failed to initialize AppEnvironment: \(error)")
        }
    }()

    init() {
        // Register the MetricKit subscriber as early as possible so the very
        // first daily payload after install is captured. Idempotent.
        MetricsCollector.shared.register()
    }

    var body: some Scene {
        RootScene(environment: Self.environment)
    }
}
