import Foundation
import CoreModels

/// Six curated records for App Store marketing screenshots. Coordinates are
/// chosen so two records sit within 1 mile of the fixed SF screenshot origin
/// (`ScreenshotLocationService.origin`) and four sit clearly farther — the
/// distance sort then renders the "≤ 1 mile" group divider with two cards
/// above it and four below.
///
/// Stable UUIDs use the reserved `DEBC1102-…` prefix so they never collide
/// with the existing debug seeders (`DEBC1100-…`, `DEBC1101-…`) or with
/// production records (random UUIDs).
enum ScreenshotSeeder {

    static var records: [Record] {
        let now = Date()
        return seeds.enumerated().map { index, seed in
            let stamp = now.addingTimeInterval(-Double(index) * 60)
            return Record(
                id: seed.id,
                name: seed.name,
                description: seed.description,
                photoID: nil,
                location: seed.location,
                zodiacSign: seed.zodiac,
                createdAt: stamp,
                updatedAt: stamp,
                metadata: RecordMetadata(timeOfDay: seed.timeOfDay, moonPhase: seed.moon)
            )
        }
    }

    private struct Seed {
        let id: UUID
        let name: String
        let description: String
        let zodiac: ZodiacSign
        let moon: MoonPhase
        let timeOfDay: TimeOfDay
        let location: LocationInfo
    }

    private static let seeds: [Seed] = [
        Seed(
            id: UUID(uuidString: "DEBC1102-0000-0000-0000-000000000001")!,
            name: "Iris",
            description: "barista at Caffe Rossi",
            zodiac: .aries,
            moon: .waxingCrescent,
            timeOfDay: .sunrise,
            // ~0.3 mi north of SF origin (37.7749, -122.4194)
            location: LocationInfo(latitude: 37.7793, longitude: -122.4194, label: "Mission District")
        ),
        Seed(
            id: UUID(uuidString: "DEBC1102-0000-0000-0000-000000000002")!,
            name: "Dashiell",
            description: "sat next to on the L train",
            zodiac: .scorpio,
            moon: .thirdQuarter,
            timeOfDay: .midnight,
            // ~0.8 mi southeast of SF origin
            location: LocationInfo(latitude: 37.7676, longitude: -122.4117, label: "SoMa")
        ),
        Seed(
            id: UUID(uuidString: "DEBC1102-0000-0000-0000-000000000003")!,
            name: "Marisol",
            description: "behind me in line at the museum",
            zodiac: .gemini,
            moon: .fullMoon,
            timeOfDay: .midday,
            location: LocationInfo(latitude: 40.7794, longitude: -73.9632, label: "The Met")
        ),
        Seed(
            id: UUID(uuidString: "DEBC1102-0000-0000-0000-000000000004")!,
            name: "Theo",
            description: "bartender, the rooftop place",
            zodiac: .leo,
            moon: .waningGibbous,
            timeOfDay: .night,
            location: LocationInfo(latitude: 34.0522, longitude: -118.2437, label: "Downtown LA")
        ),
        Seed(
            id: UUID(uuidString: "DEBC1102-0000-0000-0000-000000000005")!,
            name: "Anya",
            description: "met at Polly's birthday",
            zodiac: .sagittarius,
            moon: .firstQuarter,
            timeOfDay: .dusk,
            location: LocationInfo(latitude: 41.8781, longitude: -87.6298, label: "Chicago")
        ),
        Seed(
            id: UUID(uuidString: "DEBC1102-0000-0000-0000-000000000006")!,
            name: "Wren",
            description: "corner table at Sqirl",
            zodiac: .virgo,
            moon: .waxingGibbous,
            timeOfDay: .midday,
            location: LocationInfo(latitude: 34.0954, longitude: -118.2723, label: "Silver Lake")
        ),
    ]
}
