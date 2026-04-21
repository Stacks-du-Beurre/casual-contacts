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

    /// Harness that provides a real `@FocusState` binding so `CreateFormOverlay`
    /// can be constructed inside a `View` context.
    private struct Harness: View {
        @Bindable var model: CreateRecordModel
        @FocusState var focused: Bool

        var body: some View {
            CreateFormOverlay(
                model: model,
                nameFocused: $focused,
                attitude: .zero,
                backdropSize: CGSize(width: 400, height: 800),
                coordinateSpaceName: "test",
                onAddPhoto: {},
                backdrop: { Color.clear }
            )
        }
    }

    @Test func instantiatesEmpty() {
        let model = makeModel()
        _ = Harness(model: model).body
    }

    @Test func instantiatesPopulated() {
        let model = makeModel(name: "Adam", description: "Met at midday")
        _ = Harness(model: model).body
    }
}
