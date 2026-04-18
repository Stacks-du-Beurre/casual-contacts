import SwiftUI
import AppFeature

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

    var body: some Scene {
        RootScene(environment: Self.environment)
    }
}
