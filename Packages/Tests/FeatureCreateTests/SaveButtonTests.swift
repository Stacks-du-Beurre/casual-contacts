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
}
