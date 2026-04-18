import Testing
import SwiftUI
@testable import DesignSystem

@Suite struct GradientsTests {

    @Test func namedGradientsExist() {
        _ = CCDesign.Gradients.dawn
        _ = CCDesign.Gradients.sunrise
        _ = CCDesign.Gradients.midday
        _ = CCDesign.Gradients.sunset
        _ = CCDesign.Gradients.dusk
        _ = CCDesign.Gradients.night
        _ = CCDesign.Gradients.midnight
    }

    @Test func allIsSevenGradients() {
        #expect(CCDesign.Gradients.all.count == 7)
    }
}
