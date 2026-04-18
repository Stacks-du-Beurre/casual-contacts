import Testing
import Foundation
import CoreModels
@testable import Visuals

@Suite struct ZodiacLayerTests {

    @Test func figureAssetsExistForAllSigns() {
        let bundle = Bundle.module
        for sign in ZodiacSign.allCases {
            let name = ZodiacLayer.assetName(for: sign, variant: .figure)
            let url = bundle.url(forResource: name, withExtension: "svg", subdirectory: "Zodiac")
                ?? bundle.url(forResource: name, withExtension: "svg")
            #expect(url != nil, "Missing zodiac figure asset: \(name)")
        }
    }

    @Test func constellationAssetsExistForAllSigns() {
        let bundle = Bundle.module
        for sign in ZodiacSign.allCases {
            let name = ZodiacLayer.assetName(for: sign, variant: .constellation)
            let url = bundle.url(forResource: name, withExtension: "svg", subdirectory: "Zodiac")
                ?? bundle.url(forResource: name, withExtension: "svg")
            #expect(url != nil, "Missing zodiac constellation asset: \(name)")
        }
    }

    @Test func flatAttitudeHasZeroTranslation() {
        let t = ZodiacLayer.translation(for: .zero)
        #expect(t.width == 0 && t.height == 0)
    }
}
