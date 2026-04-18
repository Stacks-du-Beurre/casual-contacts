import Testing
import SwiftUI
@testable import Visuals

@Suite struct GuillocheRotationLayerTests {

    @Test func layerInstantiatesWithEmptyPaths() {
        let layer = GuillocheRotationLayer(paths: [])
        _ = layer.body
    }

    @Test func layerInstantiatesWithSinglePath() {
        let sample = Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: 10, y: 10)) }
        let layer = GuillocheRotationLayer(paths: [sample])
        _ = layer.body
    }
}
