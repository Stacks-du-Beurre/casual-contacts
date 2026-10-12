import Foundation
import Testing
import CoreModels
@testable import Visuals

@Suite struct WindowSceneProjectionTests {
    private func scene(cardCentered: Bool = true) -> WindowSceneProjection {
        WindowSceneProjection(eye: ViewerPosition(x: 0, y: 0, distance: 0.4),
                              reference: ViewerPosition(x: 0.03, y: 0.06, distance: 0.4),
                              backingDepthMeters: 0.06, spacing: 1, screenWidthMeters: 0.1,
                              viewport: CGSize(width: 1000, height: 2000),
                              cardCenteredReference: cardCentered)
    }

    @Test func centeredCardHasNoArtificialLateralOrVerticalBias() {
        let value = scene()
        let frame = CGRect(x: 300, y: 900, width: 400, height: 200)
        let projection = WindowPlaneProjection(eye: value.eye, reference: value.reference(for: frame), depth: 0.06)!
        #expect(abs(projection.translationX) < 1e-9)
        #expect(abs(projection.translationY) < 1e-9)
    }

    @Test func scrollingCardChangesPerspectiveAndOppositeCardsAreSymmetric() {
        let value = scene()
        let upper = CGRect(x: 300, y: 500, width: 400, height: 200)
        let lower = upper.offsetBy(dx: 0, dy: 800)
        let a = WindowPlaneProjection(eye: value.eye, reference: value.reference(for: upper), depth: 0.06)!
        let b = WindowPlaneProjection(eye: value.eye, reference: value.reference(for: lower), depth: 0.06)!
        #expect(a.translationY < 0)
        #expect(b.translationY > 0)
        #expect(abs(a.translationY + b.translationY) < 1e-9)
        let scrolled = lower.offsetBy(dx: 0, dy: -400)
        let c = WindowPlaneProjection(eye: value.eye, reference: value.reference(for: scrolled), depth: 0.06)!
        #expect(abs(c.translationY) < 1e-9)
    }

    @Test func expandedSceneKeepsApprovedCalibration() {
        let value = scene(cardCentered: false)
        let reference = value.reference(for: CGRect(x: 300, y: 900, width: 400, height: 200))
        #expect(reference.x == value.reference.x)
        #expect(reference.y == value.reference.y)
    }
}
