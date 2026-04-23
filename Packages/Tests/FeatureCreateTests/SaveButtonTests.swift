import Testing
import SwiftUI
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct SaveButtonTests {

    @Test func instantiatesEnabled() {
        var tapped = 0
        let button = SaveButton(
            isEnabled: true,
            timeOfDay: .midday,
            attitude: .zero,
            action: { tapped += 1 }
        )
        _ = button.body
        button.action()
        #expect(tapped == 1)
    }

    @Test func instantiatesDisabled() {
        _ = SaveButton(
            isEnabled: false,
            timeOfDay: .night,
            attitude: .zero,
            action: {}
        ).body
    }

    @Test func customLabelRendersInsteadOfDefault() {
        let button = SaveButton(
            label: "UPDATE",
            isEnabled: true,
            timeOfDay: .midday,
            attitude: .zero,
            action: {}
        )
        let mirror = Mirror(reflecting: button)
        let labelProperty = mirror.children.first { $0.label == "label" }
        #expect((labelProperty?.value as? String) == "UPDATE")
    }
}
