import Testing
import SwiftUI
@testable import AppFeature

@MainActor
@Suite struct LocationPermissionPrimerViewTests {
    @Test func primerViewInstantiates() {
        _ = LocationPermissionPrimer(onAccept: {}, onDecline: {}).body
    }
}
