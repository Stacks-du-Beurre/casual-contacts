import Foundation
import Testing
import CoreModels
@testable import Visuals

@Suite struct WindowSceneProjectionTests {
    @Test func liveGeometryFindsCardOriginWhileScrolling() {
        let local = CGRect(x: 40, y: 60, width: 184, height: 160)
        let size = CGSize(width: 370, height: 211)
        let first = WindowSceneProjection.cardFrame(local: local, global: local.offsetBy(dx: 16, dy: 320), size: size)
        let scrolled = WindowSceneProjection.cardFrame(local: local, global: local.offsetBy(dx: 16, dy: 120), size: size)
        #expect(first == CGRect(x: 16, y: 320, width: 370, height: 211))
        #expect(scrolled == first.offsetBy(dx: 0, dy: -200))
    }
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

    @Test func returningCardMatchesItsListReferenceAtHandoff() {
        let frame = CGRect(x: 16, y: 250, width: 370, height: 211)
        let full = scene(cardCentered: false)
        let list = scene(cardCentered: true)
        let returned = full.expanding(progress: 0, sourceUsesWindowScene: true)
        #expect(returned.reference(for: frame) == list.reference(for: frame))
        #expect(returned.backingDepthMeters == list.backingDepthMeters)
        let a = WindowPlaneProjection(eye: returned.eye, reference: returned.reference(for: frame), depth: 0.06)!
        let b = WindowPlaneProjection(eye: list.eye, reference: list.reference(for: frame), depth: 0.06)!
        #expect(a.translationX == b.translationX)
        #expect(a.translationY == b.translationY)
        #expect(a.scale == b.scale)
    }

    @Test func referenceBlendsWithoutChangingFullScreenCalibration() {
        let frame = CGRect(x: 16, y: 250, width: 370, height: 211)
        let full = scene(cardCentered: false)
        let listReference = scene().reference(for: frame)
        let mid = full.expanding(progress: 0.5, sourceUsesWindowScene: true).reference(for: frame)
        #expect(abs(mid.x - (listReference.x + full.reference.x) / 2) < 1e-9)
        #expect(abs(mid.y - (listReference.y + full.reference.y) / 2) < 1e-9)
        #expect(full.expanding(progress: 1, sourceUsesWindowScene: true).reference(for: frame) == full.reference)
        #expect(full.expanding(progress: 0, sourceUsesWindowScene: false).backingDepthMeters == 0)
    }
}
