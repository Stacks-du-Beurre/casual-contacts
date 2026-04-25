import Foundation
import CoreModels

/// Hand-authored fixtures for QA — one record per `TimeOfDay` so each
/// gradient can be eyeballed in the list at the same time. The seven UUIDs
/// below are stable + reserved (zero-padded prefix `DEBC1100…`); the seeder
/// uses them to identify which records to delete when the tester taps
/// "Remove debug records". Production records use random UUIDs and won't
/// collide.
///
/// Locations are real-world city coordinates so the eventual location-sort
/// feature has something to compute distances against.
enum DebugRecordSeeder {

    /// All seed records. Order chosen so they sort sensibly in the list
    /// (newest first by `createdAt`, descending across the day).
    static var records: [Record] {
        let now = Date()
        return seeds.enumerated().map { index, seed in
            // Stagger createdAt by index so the list ordering is stable
            // and matches the array order top-to-bottom.
            let stamp = now.addingTimeInterval(-Double(index))
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

    /// IDs of the seven seed records. Used by the "Remove debug records"
    /// action to find + delete only the seeded fixtures.
    static var ids: [UUID] {
        seeds.map(\.id)
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
            id: UUID(uuidString: "DEBC1100-0000-0000-0000-000000000001")!,
            name: "Aurora",
            description: "Met at a coffee shop just before the sun came up",
            zodiac: .aries,
            moon: .firstQuarter,
            timeOfDay: .dawn,
            location: LocationInfo(latitude: 35.6762, longitude: 139.6503, label: "Tokyo, Japan")
        ),
        Seed(
            id: UUID(uuidString: "DEBC1100-0000-0000-0000-000000000002")!,
            name: "Sunny",
            description: "Spotted picking peaches at the morning farmers market",
            zodiac: .leo,
            moon: .waxingCrescent,
            timeOfDay: .sunrise,
            location: LocationInfo(latitude: -33.8688, longitude: 151.2093, label: "Sydney, Australia")
        ),
        Seed(
            id: UUID(uuidString: "DEBC1100-0000-0000-0000-000000000003")!,
            name: "Noah",
            description: "Read on the same park bench every lunch",
            zodiac: .virgo,
            moon: .waxingGibbous,
            timeOfDay: .midday,
            location: LocationInfo(latitude: 51.5074, longitude: -0.1278, label: "London, UK")
        ),
        Seed(
            id: UUID(uuidString: "DEBC1100-0000-0000-0000-000000000004")!,
            name: "Iris",
            description: "Bumped into at a rooftop happy hour overlooking the river",
            zodiac: .libra,
            moon: .fullMoon,
            timeOfDay: .sunset,
            location: LocationInfo(latitude: 48.8566, longitude: 2.3522, label: "Paris, France")
        ),
        Seed(
            id: UUID(uuidString: "DEBC1100-0000-0000-0000-000000000005")!,
            name: "Eve",
            description: "Stood next to me at a gallery opening as the sky turned",
            zodiac: .scorpio,
            moon: .waningGibbous,
            timeOfDay: .dusk,
            location: LocationInfo(latitude: 40.7128, longitude: -74.0060, label: "New York, NY")
        ),
        Seed(
            id: UUID(uuidString: "DEBC1100-0000-0000-0000-000000000006")!,
            name: "Luna",
            description: "Caught up at a rooftop bar long after sundown",
            zodiac: .capricorn,
            moon: .thirdQuarter,
            timeOfDay: .night,
            location: LocationInfo(latitude: 52.5200, longitude: 13.4050, label: "Berlin, Germany")
        ),
        Seed(
            id: UUID(uuidString: "DEBC1100-0000-0000-0000-000000000007")!,
            name: "Atlas",
            description: "Stayed up trading stories until well past two in the morning",
            zodiac: .aquarius,
            moon: .waningCrescent,
            timeOfDay: .midnight,
            location: LocationInfo(latitude: 37.7749, longitude: -122.4194, label: "San Francisco, CA")
        ),
    ]
}
