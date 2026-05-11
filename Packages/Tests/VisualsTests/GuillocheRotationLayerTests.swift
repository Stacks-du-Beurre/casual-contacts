import Testing
import SwiftUI
@testable import Visuals

@MainActor
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

    @Test func rotatingRenderSurfaceContainsNativeViewBoxAtAnyAngle() {
        let side = GuillocheRotationLayer.rotatingRenderSide(forNativeSide: 380)
        let requiredSide = 380 * sqrt(2)

        #expect(side >= requiredSide)
        #expect(GuillocheRotationLayer.nativeViewBoxOffset(inRenderSide: side, nativeSide: 380) > 0)
    }
}
