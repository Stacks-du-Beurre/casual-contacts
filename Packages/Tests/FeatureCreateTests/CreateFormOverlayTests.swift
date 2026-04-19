import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct CreateFormOverlayTests {

    private func makeModel(name: String = "", description: String = "") -> CreateRecordModel {
        let model = CreateRecordModel(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            metadata: RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon),
            location: nil
        )
        model.name = name
        model.description = description
        return model
    }

    @Test func instantiatesEmpty() {
        let model = makeModel()
        _ = CreateFormOverlay(model: model).body
    }

    @Test func instantiatesPopulated() {
        let model = makeModel(name: "Adam", description: "Met at midday")
        _ = CreateFormOverlay(model: model).body
    }
}
