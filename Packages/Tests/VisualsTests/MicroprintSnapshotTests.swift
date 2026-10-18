#if canImport(UIKit)
import CoreModels
import CoreText
import DesignSystem
import SnapshotTesting
import SwiftUI
import Testing
import UIKit
@testable import Visuals

@MainActor struct MicroprintSnapshotTests {
    @Test func engravedPlates() throws {
        for name in ["IBMPlexMono-Regular", "CormorantSC-SemiBold"] {
            if let url = CCDesign.bundle.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        for (key, name, place) in [("latin", "Iris Rossi", "Mission District"),
                                    ("cyrillic", "Олена Іваненко", "Київ · Поділ")] {
            let record = Record(id: UUID(uuidString: "DEBC1102-0000-0000-0000-000000000011")!,
                                name: name, description: "", photoID: nil,
                                location: LocationInfo(latitude: 0, longitude: 0, label: place),
                                zodiacSign: nil, createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                                updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                                metadata: RecordMetadata(timeOfDay: .night, moonPhase: .fullMoon))
            let inscription = MicroprintInscription(record: record)
            let first = try #require(MicroprintTexture.image(for: inscription))
            let second = try #require(MicroprintTexture.image(for: inscription))
            #expect(first === second, "Motion must reuse the prepared engraving")
            #expect(first.bitsPerPixel == 8)
            #expect(first.bytesPerRow * first.height < 1_600_000)
            let view = CardMicroprintLayer(record: record, expansion: 1)
                .frame(width: 400, height: 400)
                .background(Color(red: 0.12, green: 0.15, blue: 0.22))
            assertSnapshot(of: UIHostingController(rootView: view),
                           as: .image(size: CGSize(width: 400, height: 400)), named: key)
        }
    }
}
#endif
