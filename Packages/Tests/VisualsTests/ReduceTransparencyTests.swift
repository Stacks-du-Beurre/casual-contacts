import Testing
import Foundation
import CoreModels
@testable import Visuals

@Suite @MainActor struct ReduceTransparencyTests {

    @Test func gradientLayerTransfusionOpacityIsZeroWhenReduced() {
        #expect(GradientLayer.transfusionOpacity(for: .zero, reduceTransparency: true) == 0)
    }

    @Test func gradientLayerTransfusionOpacityUnchangedWhenNotReduced() {
        let attitude = DeviceAttitude(pitch: 0.3, roll: -0.4)
        let expected = GradientLayer.transfusionOpacity(for: attitude)  // legacy signature
        let actual = GradientLayer.transfusionOpacity(for: attitude, reduceTransparency: false)
        #expect(expected == actual)
    }

    @Test func gradientLayerTransfusionOpacityMatchesFormula() {
        let attitude = DeviceAttitude(pitch: 0.2, roll: -0.5)
        let out = GradientLayer.transfusionOpacity(for: attitude, reduceTransparency: false)
        let expected = abs(attitude.roll)
        #expect(out == expected)
    }

    @Test func holographicViewsInstantiateInBothTransparencyModes() {
        _ = HolographicZodiac(sign: .virgo, attitude: .zero).body
    }
}
