import Testing
import SwiftUI
@testable import FeatureCreate

@MainActor
@Suite struct PersonTopNavTests {

    @Test func instantiatesWithCallbacks() {
        var cancelCount = 0
        let nav = PersonTopNav(onCancel: { cancelCount += 1 })
        _ = nav.body
        // Sanity: callback is still callable (view doesn't have to invoke it).
        nav.onCancel()
        #expect(cancelCount == 1)
    }

    @Test func customTitleRendersInsteadOfDefault() {
        let nav = PersonTopNav(title: "EDIT", onCancel: {})
        let mirror = Mirror(reflecting: nav)
        let titleProperty = mirror.children.first { $0.label == "title" }
        #expect((titleProperty?.value as? String) == "EDIT")
    }
}
