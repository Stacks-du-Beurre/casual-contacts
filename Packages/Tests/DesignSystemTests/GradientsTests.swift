import Testing
import SwiftUI
@testable import DesignSystem
#if canImport(UIKit)
import UIKit
#endif

@Suite struct GradientsTests {

    private static let names = ["Dawn", "Sunrise", "Midday", "Sunset", "Dusk", "Night", "Midnight"]

    #if canImport(UIKit)
    @Test func allSevenBitmapsResolveFromBundle() {
        for name in Self.names {
            let image = UIImage(named: name, in: .designSystemBundle, compatibleWith: nil)
            #expect(image != nil, "\(name) must be resolvable from DesignSystem bundle")
        }
    }
    #endif

    @Test func allContainsSevenBackdrops() {
        #expect(CCDesign.Gradients.all.count == 7)
    }

    @Test func viewForTimeOfDayReturnsAllSevenDistinct() {
        let all: [CCDesign.GradientBackdrop] = [
            CCDesign.Gradients.view(for: .dawn),
            CCDesign.Gradients.view(for: .sunrise),
            CCDesign.Gradients.view(for: .midday),
            CCDesign.Gradients.view(for: .sunset),
            CCDesign.Gradients.view(for: .dusk),
            CCDesign.Gradients.view(for: .night),
            CCDesign.Gradients.view(for: .midnight),
        ]
        let uniqueNames = Set(all.map(\.assetName))
        #expect(uniqueNames.count == 7)
    }
}
