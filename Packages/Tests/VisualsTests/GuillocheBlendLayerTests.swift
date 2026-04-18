import Testing
import SwiftUI
import CoreModels
@testable import Visuals

@Suite struct GuillocheBlendLayerTests {

    private func makePaths(count: Int) -> [Path] {
        (0..<count).map { _ in
            Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: 10, y: 10)) }
        }
    }

    @Test func flatAttitudeKeepsAllPathsAtSamePosition() {
        // Not easily testable directly through View body — we expose the offset helper.
        for i in 0..<15 {
            let offset = GuillocheBlendLayer.offset(forPathIndex: i, attitude: .zero)
            #expect(offset.width == 0)
            #expect(offset.height == 0)
        }
    }

    @Test func tiltedAttitudeSpreadsPathsByDepth() {
        let attitude = DeviceAttitude(pitch: 0.5, roll: 0.5)
        let innerOffset = GuillocheBlendLayer.offset(forPathIndex: 0, attitude: attitude)
        let outerOffset = GuillocheBlendLayer.offset(forPathIndex: 14, attitude: attitude)

        #expect(abs(outerOffset.width) > abs(innerOffset.width))
        #expect(abs(outerOffset.height) > abs(innerOffset.height))
    }

    @Test @MainActor func layerInstantiatesAtEveryDensity() {
        let paths15 = makePaths(count: 15)
        let paths7 = makePaths(count: 7)
        _ = GuillocheBlendLayer(paths: paths15, density: .cards, attitude: .zero).body
        _ = GuillocheBlendLayer(paths: paths7, density: .recommended, attitude: .zero).body
        _ = GuillocheBlendLayer(paths: paths7, density: .preview, attitude: .zero).body
    }
}
