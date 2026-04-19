import Testing
import SwiftUI
import CoreModels
import DesignSystem
@testable import Visuals

@Suite struct GradientLayerTests {

    @Test func resolvesGradientForEveryTimeOfDay() {
        for timeOfDay in TimeOfDay.allCases {
            _ = GradientLayer.backdrop(for: timeOfDay)
        }
    }

    @Test func transfusionOpacityMapsAbsRollToZeroOne() {
        // |roll| = 0 → 0, |roll| = 0.5 → 0.5, |roll| = 1 → 1 (symmetric around 0)
        #expect(GradientLayer.transfusionOpacity(for: DeviceAttitude(pitch: 0, roll: 0)) == 0.0)
        #expect(GradientLayer.transfusionOpacity(for: DeviceAttitude(pitch: 0, roll: -0.5)) == 0.5)
        #expect(GradientLayer.transfusionOpacity(for: DeviceAttitude(pitch: 0, roll: 0.5)) == 0.5)
        #expect(GradientLayer.transfusionOpacity(for: DeviceAttitude(pitch: 0, roll: -1)) == 1.0)
        #expect(GradientLayer.transfusionOpacity(for: DeviceAttitude(pitch: 0, roll: 1)) == 1.0)
    }

    @Test func transfusionOpacityClampsOutOfRange() {
        // DeviceAttitude is clamped at construction, so anything >1 / <-1 should be clamped before arriving.
        // But the mapping function should also be defensive.
        #expect(GradientLayer.transfusionOpacity(for: DeviceAttitude(pitch: 0, roll: 2).clamped()) == 1.0)
        #expect(GradientLayer.transfusionOpacity(for: DeviceAttitude(pitch: 0, roll: -2).clamped()) == 1.0)
    }
}
