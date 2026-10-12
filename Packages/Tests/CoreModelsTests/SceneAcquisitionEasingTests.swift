import Testing
import CoreModels

@Suite struct SceneAcquisitionEasingTests {
    @Test func delayedFaceStartsGraduallyAndLossDoesNotCollapseScene() {
        var model = SceneAcquisitionEasing()
        for _ in 0..<60 { #expect(model.step(hasPose: false, elapsed: 1.0 / 60) == 0) }
        let first = model.step(hasPose: true, elapsed: 1.0 / 60)
        #expect(first > 0 && first < 0.02)
        for _ in 0..<30 { model.step(hasPose: true, elapsed: 1.0 / 60) }
        #expect(model.value == 1)
        #expect(model.step(hasPose: false, elapsed: 1) == 1)
        #expect(model.step(hasPose: true, elapsed: 1.0 / 60) == 1)
    }

    @Test func acquisitionDurationIsIndependentOfDisplayRate() {
        var thirty = SceneAcquisitionEasing()
        var sixty = SceneAcquisitionEasing()
        for _ in 0..<6 { thirty.step(hasPose: true, elapsed: 1.0 / 30) }
        for _ in 0..<12 { sixty.step(hasPose: true, elapsed: 1.0 / 60) }
        #expect(abs(thirty.value - sixty.value) < 1e-9)
        #expect(thirty.value > 0.49 && thirty.value < 0.51)
    }
}
