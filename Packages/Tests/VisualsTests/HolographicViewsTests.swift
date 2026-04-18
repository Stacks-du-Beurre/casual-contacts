import Testing
import SwiftUI
import CoreModels
@testable import Visuals

@Suite struct HolographicViewsTests {

    @Test @MainActor func holographicZodiacInstantiates() {
        _ = HolographicZodiac(sign: .virgo, attitude: .zero).body
    }
}
