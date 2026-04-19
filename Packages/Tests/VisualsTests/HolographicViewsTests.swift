import Testing
import SwiftUI
import CoreModels
@testable import Visuals

@Suite struct HolographicViewsTests {

    @Test @MainActor func holographicZodiacInstantiates() {
        _ = HolographicZodiac(sign: .virgo, attitude: .zero).body
    }

    @Test @MainActor func hologramTextInstantiatesAtZeroAttitude() {
        _ = HologramText(
            "jane",
            font: .system(size: 33),
            attitude: .zero,
            backdropSize: CGSize(width: 335, height: 211),
            coordinateSpaceName: "CardScene",
            backdrop: { Color.clear }
        ).body
    }

    @Test @MainActor func hologramTextInstantiatesAtFullTilt() {
        _ = HologramText(
            "jane",
            font: .system(size: 33),
            attitude: DeviceAttitude(pitch: 1.0, roll: 1.0),
            backdropSize: CGSize(width: 335, height: 211),
            coordinateSpaceName: "CardScene",
            backdrop: { Color.clear }
        ).body
    }

    @Test func hologramTextTuningConstantsMatchSpec() {
        // Locks the tuning surface so a silent edit to the defaults shows up
        // as a test diff the reviewer must explain. Values are calibrated
        // against the PDF §5 Title/Name sample on iPhone 11 Pro (375pt).
        #expect(HologramText<Color>.translationScaleX == 12)
        #expect(HologramText<Color>.translationScaleY == 8)
        #expect(HologramText<Color>.rotationDegrees == 6)
        #expect(HologramText<Color>.textureOverscan == 1.3)
    }
}
