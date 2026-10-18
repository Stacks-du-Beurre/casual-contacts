import CoreModels
import Foundation
import Testing
@testable import Visuals

struct SecurityThreadTests {
    static func record(name: String = "Iris Rossi") -> Record {
        Record(id: UUID(uuidString: "DEBC1102-0000-0000-0000-000000000011")!,
               name: name, description: "", photoID: nil, location: nil,
               zodiacSign: nil, createdAt: Date(timeIntervalSince1970: 1_700_000_000),
               updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
               metadata: RecordMetadata(timeOfDay: .night, moonPhase: .fullMoon))
    }

    @Test func colourUsesEncounterDateAndSurvivesEditing() {
        let original = Self.record()
        let first = SecurityThreadInscription(record: original)
        #expect(first.annualPhase > 0.86 && first.annualPhase < 0.88)
        var edited = original
        edited.name = "A different name"
        edited.updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(SecurityThreadInscription(record: edited) == first)
        #expect(SecurityThreadPalette(annualPhase: 0) == SecurityThreadPalette(annualPhase: 1))
        #expect(SecurityThreadPalette(annualPhase: .infinity) == SecurityThreadPalette(annualPhase: 0))
        #expect(SecurityThreadPalette(annualPhase: 0) != SecurityThreadPalette(annualPhase: 0.5))
    }

    @Test func reflectionsRemainFiniteAtTrackingExtremes() {
        let input = SecurityThreadLight(horizontal: .infinity, vertical: -.infinity)
        #expect(input == .zero)
        #expect(SecurityThreadLight(horizontal: 20, vertical: -20) ==
                SecurityThreadLight(horizontal: 1, vertical: -1))
        #expect(SecurityThreadLight(scene: nil, attitude: DeviceAttitude(pitch: 0.4, roll: -0.3)) ==
                SecurityThreadLight(horizontal: -0.3, vertical: 0.4))
    }

    @MainActor @Test func engravingIsSmallAndReusedBetweenMotionFrames() throws {
        #if canImport(UIKit)
        Self.registerFonts()
        #endif
        let inscription = SecurityThreadInscription(record: Self.record())
        let first = try #require(SecurityThreadEngraving.image(for: inscription))
        let second = try #require(SecurityThreadEngraving.image(for: inscription))
        #expect(first === second)
        #expect(first.bitsPerPixel == 8)
        #expect(first.bytesPerRow * first.height < 520_000)
        let otherDate = Record(id: Self.record().id, name: "", description: "", photoID: nil,
            location: nil, zodiacSign: nil, createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0), metadata: Self.record().metadata)
        #expect(first === SecurityThreadEngraving.image(for: SecurityThreadInscription(record: otherDate)),
                "Changing the date colour must not allocate a second engraving")
    }

    @MainActor @Test func preparesArtworkOffTheUIThread() async throws {
        #if canImport(UIKit)
        Self.registerFonts()
        #endif
        let inscription = SecurityThreadInscription(record: Self.record(name: "Offthread test"))
        let prepared = await Task.detached {
            Self.prepareInBackground(inscription)
        }.value
        #expect(prepared.engraving != nil)
    }

    private static func prepareInBackground(_ inscription: SecurityThreadInscription) -> SecurityThreadPrepared {
        #expect(!Thread.isMainThread)
        return SecurityThreadPrepared(inscription: inscription)
    }
}

#if canImport(UIKit)
import CoreText
import DesignSystem
import SnapshotTesting
import SwiftUI
import UIKit

@MainActor struct SecurityThreadSnapshotTests {
    @Test func foilAtDifferentAngles() {
        SecurityThreadTests.registerFonts()
        let inscription = SecurityThreadInscription(record: SecurityThreadTests.record())
        for (name, light) in [("center", SecurityThreadLight.zero),
                              ("left", SecurityThreadLight(horizontal: -0.8, vertical: -0.6)),
                              ("right", SecurityThreadLight(horizontal: 0.8, vertical: 0.6))] {
            let view = SecurityThreadSurface(inscription: inscription, light: light, expansion: 1)
                .frame(width: 80, height: 800)
                .background(Color(red: 0.12, green: 0.15, blue: 0.22))
            assertSnapshot(of: UIHostingController(rootView: view),
                           as: .image(size: CGSize(width: 80, height: 800)), named: name)
        }
        let compact = SecurityThreadCompact(inscription: inscription, light: .zero)
            .frame(width: 80, height: 220)
            .background(Color(red: 0.12, green: 0.15, blue: 0.22))
        assertSnapshot(of: UIHostingController(rootView: compact),
                       as: .image(size: CGSize(width: 80, height: 220)), named: "compact")
        if let image = SecurityThreadEngraving.image(for: inscription) {
            let engraving = Image(decorative: image, scale: 3)
                .resizable().renderingMode(.template).foregroundStyle(.white)
                .frame(width: 64, height: 640).background(.black)
            assertSnapshot(of: UIHostingController(rootView: engraving),
                           as: .image(size: CGSize(width: 64, height: 640)), named: "engraving")
        }

    }
}

extension SecurityThreadTests {
    @MainActor static func registerFonts() {
        for name in ["IBMPlexMono-Regular", "CormorantSC-SemiBold"] {
            if let url = CCDesign.bundle.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
#endif
