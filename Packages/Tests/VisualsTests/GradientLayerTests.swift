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

    @Test func transfusionOpacityGainAmplifiesAndClamps() {
        // gain = 2 → roll = 0.5 already reaches the curve's edge in one-sided mode.
        // gain > 1 must clamp at the curve's endpoint, not exceed 1.0.
        let oneSided: (Double, Double) -> Double = { roll, gain in
            GradientLayer.transfusionOpacity(
                for: DeviceAttitude(pitch: 0, roll: roll),
                mode: .oneSidedAtRest,
                gain: gain,
                reduceTransparency: false
            )
        }
        #expect(oneSided(0.25, 2.0) == 0.5)
        #expect(oneSided(0.5, 2.0)  == 1.0)
        #expect(oneSided(0.8, 2.0)  == 1.0)   // 1.6 clamps to 1.0 → |1.0| = 1.0
        #expect(oneSided(-0.5, 2.0) == 1.0)
        #expect(oneSided(0.5, 0.5)  == 0.25)  // gain < 1 reduces sensitivity

        // .balancedAtRest with gain: signed scaled roll drives the curve.
        let balanced: (Double, Double) -> Double = { roll, gain in
            GradientLayer.transfusionOpacity(
                for: DeviceAttitude(pitch: 0, roll: roll),
                mode: .balancedAtRest,
                gain: gain,
                reduceTransparency: false
            )
        }
        #expect(balanced(0,    2.0) == 0.5)   // rest unaffected by gain
        #expect(balanced(0.5,  2.0) == 1.0)   // half-roll, doubled = +1 → 1.0
        #expect(balanced(-0.5, 2.0) == 0.0)
        #expect(balanced(0.8,  2.0) == 1.0)   // clamped: 1.6 → 1.0 → 0.5+0.5 = 1.0
    }

    @Test func transfusionOpacityBalancedAtRestIsHalf() {
        // .balancedAtRest: signed mapping. Rest = 0.5, +1 = 1.0, −1 = 0.0.
        let opacity: (Double) -> Double = { roll in
            GradientLayer.transfusionOpacity(
                for: DeviceAttitude(pitch: 0, roll: roll),
                mode: .balancedAtRest,
                reduceTransparency: false
            )
        }
        #expect(opacity(0)    == 0.5)
        #expect(opacity(1)    == 1.0)
        #expect(opacity(-1)   == 0.0)
        #expect(opacity(0.5)  == 0.75)
        #expect(opacity(-0.5) == 0.25)
    }
}
