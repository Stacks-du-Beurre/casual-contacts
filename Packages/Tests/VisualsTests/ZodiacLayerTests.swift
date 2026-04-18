import Testing
import Foundation
import CoreModels
@testable import Visuals

@Suite struct ZodiacLayerTests {

    @Test
    @MainActor
    func layerInstantiatesForEverySign() {
        for sign in ZodiacSign.allCases {
            for variant in [ZodiacLayer.Variant.figure, .constellation] {
                let layer = ZodiacLayer(sign: sign, attitude: .zero, variant: variant)
                _ = layer.body  // verify no crash during view construction
            }
        }
    }

    @Test func flatAttitudeHasZeroTranslation() {
        let t = ZodiacLayer.translation(for: .zero)
        #expect(t.width == 0 && t.height == 0)
    }
}
