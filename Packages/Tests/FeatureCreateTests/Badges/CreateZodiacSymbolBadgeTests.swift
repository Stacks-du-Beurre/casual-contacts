import Testing
import SwiftUI
import CoreModels
@testable import FeatureCreate

@MainActor
@Suite struct CreateZodiacSymbolBadgeTests {

    @Test func instantiatesForAllSigns() {
        for sign in ZodiacSign.allCases {
            _ = CreateZodiacSymbolBadge(sign: sign, attitude: .zero).body
        }
    }
}
