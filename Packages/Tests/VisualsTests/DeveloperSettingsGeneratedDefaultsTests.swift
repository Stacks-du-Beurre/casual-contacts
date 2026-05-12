import Testing
@testable import Visuals

@Suite @MainActor struct DeveloperSettingsGeneratedDefaultsTests {
    @Test func generatedVisualDefaultsFeedTuningDefaults() {
        #expect(VisualDeveloperSettingsDefaults.hologram.backdropBlurOpacity == HologramTuning.Defaults.backdropBlurOpacity)
        #expect(VisualDeveloperSettingsDefaults.hologram.translationScaleX == HologramTuning.Defaults.translationScaleX)
        #expect(VisualDeveloperSettingsDefaults.cardBackdrop.depthScale == CardBlendTuning.Defaults.depthScale)
        #expect(VisualDeveloperSettingsDefaults.cardBackdrop.hideBackdrop == CardBlendTuning.Defaults.hideBackdrop)
        #expect(VisualDeveloperSettingsDefaults.gradientAndFiligree.cardOpacity == GuillocheRotationTuning.Defaults.cardOpacity)
        #expect(VisualDeveloperSettingsDefaults.elementDepth.moonPhaseLayer == CardElementDepthTuning.Defaults.moonPhaseLayer)
        #expect(VisualDeveloperSettingsDefaults.zodiacAndPhoto.photoOpacity == PhotoFocusTuning.Defaults.opacity)
        #expect(VisualDeveloperSettingsDefaults.mediumCard.aspectRatio == MediumCardSizeTuning.Defaults.aspectRatio)
    }
}
