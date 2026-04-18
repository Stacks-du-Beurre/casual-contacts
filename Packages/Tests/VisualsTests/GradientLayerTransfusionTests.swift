import Testing
import SwiftUI
import CoreModels
@testable import Visuals

@Suite @MainActor struct GradientLayerTransfusionTests {

    @Test func transfusionOpacityAtRollZeroIsDefaultFifty() {
        let opacity = GradientLayer.transfusionOpacity(
            for: DeviceAttitude(pitch: 0, roll: 0),
            reduceTransparency: false
        )
        #expect(opacity == 0.5, "Spec Default_50% requires opacity = 0.5 at roll = 0")
    }

    @Test func transfusionOpacityAtRollNegativeOneIsZero() {
        let opacity = GradientLayer.transfusionOpacity(
            for: DeviceAttitude(pitch: 0, roll: -1),
            reduceTransparency: false
        )
        #expect(opacity == 0.0)
    }

    @Test func transfusionOpacityAtRollPositiveOneIsOne() {
        let opacity = GradientLayer.transfusionOpacity(
            for: DeviceAttitude(pitch: 0, roll: 1),
            reduceTransparency: false
        )
        #expect(opacity == 1.0)
    }

    @Test func reduceTransparencyForcesZeroOpacity() {
        let opacity = GradientLayer.transfusionOpacity(
            for: DeviceAttitude(pitch: 0, roll: 0),
            reduceTransparency: true
        )
        #expect(opacity == 0.0, "Reduce Transparency collapses to bottom layer only")
    }

    @Test func backdropResolvesToDesignSystem() {
        let backdrop = GradientLayer.backdrop(for: .sunset)
        #expect(backdrop.assetName == "Sunset")
    }
}
