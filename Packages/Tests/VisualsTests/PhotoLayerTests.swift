import Testing
import SwiftUI
@testable import Visuals

@Suite struct PhotoLayerTests {

    @Test @MainActor func cardStyleInstantiates() {
        let layer = PhotoLayer(image: Image(systemName: "photo"), style: .card)
        _ = layer.body
    }

    @Test @MainActor func recommendedStyleInstantiates() {
        let layer = PhotoLayer(image: Image(systemName: "photo"), style: .recommended)
        _ = layer.body
    }
}
