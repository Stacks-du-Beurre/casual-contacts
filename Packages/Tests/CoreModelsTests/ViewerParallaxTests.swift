import Testing
import CoreModels

@Suite struct ViewerParallaxTests {
    @Test func viewpointRemainsFixedUntilExplicitRecenter() {
        var model = ViewerParallax()
        let center = ViewerPosition(x: 0, y: 0, distance: 0.4)
        #expect(model.attitude(for: center) == .zero)
        let right = ViewerPosition(x: 0.04, y: 0, distance: 0.4)
        let moved = model.attitude(for: right)!
        #expect(moved.roll > 0)
        #expect(model.attitude(for: right) == moved)
        model.reset()
        #expect(model.attitude(for: right) == .zero)
    }

    @Test func nearerEyesProduceMoreParallaxAndVerticalAxisIsScreenDown() {
        var model = ViewerParallax()
        _ = model.attitude(for: ViewerPosition(x: 0, y: 0, distance: 0.4))
        let far = model.attitude(for: ViewerPosition(x: 0.02, y: 0.02, distance: 0.6))!
        let near = model.attitude(for: ViewerPosition(x: 0.02, y: 0.02, distance: 0.3))!
        #expect(near.roll > far.roll)
        #expect(near.pitch < far.pitch)
    }

    @Test func invalidSamplesDoNotCalibrateOrEscapeBounds() {
        var model = ViewerParallax()
        #expect(model.attitude(for: ViewerPosition(x: .nan, y: 0, distance: 0.4)) == nil)
        #expect(model.attitude(for: ViewerPosition(x: 0, y: 0, distance: 0)) == nil)
        #expect(model.attitude(for: ViewerPosition(x: 0, y: 0, distance: 0.4)) == .zero)
        #expect(model.attitude(for: ViewerPosition(x: 100, y: -100, distance: 0.4)) == DeviceAttitude(pitch: 1, roll: 1))
    }

    @Test func smoothingInterpolatesBetweenSparseSamples() {
        var filter = DisplayAttitudeSmoother()
        let target = DeviceAttitude(pitch: 1, roll: -1)
        let first = filter.step(toward: target, elapsed: 1.0 / 60)
        let second = filter.step(toward: target, elapsed: 1.0 / 60)
        #expect(first.pitch > 0 && first.pitch < second.pitch && second.pitch < 1)
        #expect(second.roll == -second.pitch)
        var thirty = DisplayAttitudeSmoother()
        var sixty = DisplayAttitudeSmoother()
        for _ in 0..<30 { _ = thirty.step(toward: target, elapsed: 1.0 / 30) }
        for _ in 0..<60 { _ = sixty.step(toward: target, elapsed: 1.0 / 60) }
        #expect(abs(thirty.value.pitch - sixty.value.pitch) < 0.000001)
    }
    @Test func fixedScreenReferenceDoesNotAdoptAnOffCenterFirstFace() {
        let neutral = ViewerPosition.screenCentered(cameraHeightMeters: 0.065)
        var model = ViewerParallax(reference: neutral)
        let offCenter = ViewerPosition(x: 0.04, y: -0.035, distance: 0.4)
        let first = model.attitude(for: offCenter)!
        #expect(first.roll > 0)
        #expect(first.pitch < 0)
        #expect(model.attitude(for: neutral) == .zero)
        model.reset()
        #expect(model.attitude(for: offCenter) == first)
        #expect(model.attitude(for: ViewerPosition(x: 0, y: -0.065, distance: 0.7)) == .zero)
        #expect(model.attitude(for: ViewerPosition(x: 0, y: -0.065, distance: 0.2)) == .zero)
    }

}
