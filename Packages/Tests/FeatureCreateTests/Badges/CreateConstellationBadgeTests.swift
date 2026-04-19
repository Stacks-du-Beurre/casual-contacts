import Testing
import SwiftUI
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct CreateConstellationBadgeTests {

    @Test func instantiatesForAllSigns() {
        for sign in ZodiacSign.allCases {
            _ = CreateConstellationBadge(sign: sign, attitude: .zero).body
        }
    }

    @Test func instantiatesWithTiltedAttitude() {
        _ = CreateConstellationBadge(
            sign: .cancer,
            attitude: DeviceAttitude(pitch: -0.2, roll: 0.3)
        ).body
    }
}
