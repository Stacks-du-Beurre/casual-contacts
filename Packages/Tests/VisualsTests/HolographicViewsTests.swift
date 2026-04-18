import Testing
import SwiftUI
import CoreModels
@testable import Visuals

@Suite struct HolographicViewsTests {

    @Test @MainActor func holographicTextInstantiates() {
        _ = HolographicText(text: "Jane", attitude: .zero).body
    }

    @Test @MainActor func holographicLocationInstantiates() {
        _ = HolographicLocation(address: "1200 TREAT AVE", attitude: .zero).body
    }

    @Test @MainActor func holographicZodiacInstantiates() {
        _ = HolographicZodiac(sign: .virgo, attitude: .zero).body
    }
}
