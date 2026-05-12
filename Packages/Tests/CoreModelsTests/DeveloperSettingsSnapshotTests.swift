import Foundation
import Testing
@testable import CoreModels

@Suite struct DeveloperSettingsSnapshotTests {
    @Test func snapshotRoundTripsAllDeveloperSettings() throws {
        let snapshot = DeveloperSettingsSnapshot(
            schemaVersion: DeveloperSettingsSnapshot.currentSchemaVersion,
            exportedAt: Date(timeIntervalSince1970: 1_777_000_000),
            source: DeveloperSettingsSnapshot.Source(
                appBundleIdentifier: "com.stacksdubeurre.CasualContacts",
                appVersion: "1.0.6",
                buildNumber: "3"
            ),
            settings: DeveloperSettingsSnapshot.Settings(
                motion: .init(
                    relativeFullScaleDegrees: 61,
                    saveButtonGradientGain: 3.25,
                    zeroPointSettleDuration: 1.5
                ),
                hologram: .init(
                    backdropBlurOpacity: 0.91,
                    whiteFillOpacity: 0.42,
                    lightenOpacity: 0.17,
                    luminosityOpacity: 0.29,
                    translationScaleX: 111,
                    translationScaleY: 88,
                    rotationDegrees: 45
                ),
                cardBackdrop: .init(
                    depthScale: 7,
                    hideBackdrop: true,
                    reverseDepthOrder: true,
                    reverseMotionDirection: false,
                    rotationGuillocheMovesInsteadOfRotates: true,
                    guillocheMovementScaleX: 0.66,
                    guillocheMovementScaleY: 1.4
                ),
                diagnostics: .init(showsCardAnimationOverlay: true),
                gradientAndFiligree: .init(
                    emptyStateEdgeReach: 0.72,
                    emptyStateRotationDegrees: 80,
                    cardRotationDegrees: 31,
                    emptyStateOpacity: 0.2,
                    cardOpacity: 0.13,
                    cardPhotoOpacity: 0.22
                ),
                elementDepth: .init(
                    perspectiveAmount: 1.7,
                    isSkewEnabled: true,
                    skewAmount: 0.12,
                    moonPhaseLayer: 10,
                    zodiacGlyphLayer: 3,
                    zodiacConstellationLayer: 14
                ),
                zodiacAndPhoto: .init(
                    zodiacRotationDegrees: 250,
                    photoFaceZoom: 0.34,
                    photoOpacity: 0.44
                ),
                mediumCard: .init(aspectRatio: 1.2)
            )
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(DeveloperSettingsSnapshot.self, from: data)

        #expect(decoded == snapshot)
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.settings.motion.relativeFullScaleDegrees == 61)
        #expect(decoded.settings.cardBackdrop.hideBackdrop == true)
        #expect(decoded.settings.elementDepth.moonPhaseLayer == 10)
    }

    @Test func generatedCoreDefaultsExposeMotionSnapshotValues() {
        #expect(CoreDeveloperSettingsDefaults.motion.relativeFullScaleDegrees == MotionTuning.Defaults.relativeFullScaleDegrees)
        #expect(CoreDeveloperSettingsDefaults.motion.saveButtonGradientGain == MotionTuning.Defaults.saveButtonGradientGain)
        #expect(CoreDeveloperSettingsDefaults.motion.zeroPointSettleDuration == MotionTuning.Defaults.zeroPointSettleDuration)
    }
}
