import Testing
import Foundation
@testable import CoreModels

@Suite struct NormalizedPointTests {

    @Test func centerIsHalfHalf() {
        #expect(NormalizedPoint.center.x == 0.5)
        #expect(NormalizedPoint.center.y == 0.5)
    }

    @Test func valuesInRangePassThrough() {
        let p = NormalizedPoint(x: 0.3, y: 0.7)
        #expect(p.x == 0.3)
        #expect(p.y == 0.7)
    }

    @Test func clampsBelowZero() {
        let p = NormalizedPoint(x: -0.5, y: -2)
        #expect(p.x == 0)
        #expect(p.y == 0)
    }

    @Test func clampsAboveOne() {
        let p = NormalizedPoint(x: 1.4, y: 99)
        #expect(p.x == 1)
        #expect(p.y == 1)
    }

    @Test func roundTripsThroughJSON() throws {
        let original = NormalizedPoint(x: 0.25, y: 0.8)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(NormalizedPoint.self, from: data)
        #expect(decoded == original)
    }
}
