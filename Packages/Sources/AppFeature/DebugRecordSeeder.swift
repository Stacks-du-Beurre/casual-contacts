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

    /// IDs of the four nearby debug records. UUIDs use a separate reserved
    /// prefix `DEBC1101-…` so they never collide with the city seeds. The
    /// "Remove debug records" action deletes both lists.
    static var nearbyIDs: [UUID] {
        nearbyIDStrings.compactMap(UUID.init(uuidString:))
    }

    private static let nearbyIDStrings: [String] = [
        "DEBC1101-0000-0000-0000-000000000001",
        "DEBC1101-0000-0000-0000-000000000002",
        "DEBC1101-0000-0000-0000-000000000003",
        "DEBC1101-0000-0000-0000-000000000004",
    ]

    private static let nearbyZodiacs: [ZodiacSign] = [
        .aries, .taurus, .gemini, .cancer, .leo, .virgo,
        .libra, .scorpio, .sagittarius, .capricorn, .aquarius, .pisces,
    ]

    private static let nearbyMoonPhases: [MoonPhase] = [
        .newMoon, .waxingCrescent, .firstQuarter, .waxingGibbous,
        .fullMoon, .waningGibbous, .thirdQuarter, .waningCrescent,
    ]

    private static let nearbyTimesOfDay: [TimeOfDay] = [
        .dawn, .sunrise, .midday, .sunset, .dusk, .night, .midnight,
    ]

    private static let nearbyNames = ["Nearby A", "Nearby B", "Nearby C", "Nearby D"]

    /// Generates four records scattered randomly within 1 mile of `origin`.
    /// Coordinates are chosen via uniform-disk sampling so the points cluster
    /// realistically rather than clinging to the radius. Other metadata (time
    /// of day, moon phase, zodiac) is randomized per-record so the cards look
    /// visually distinct in the list. Wired to the developer-settings
    /// "Add 4 nearby records" row.
    static func nearbyRecords(
        around origin: LocationInfo,
        now: Date = Date(),
        rng: inout some RandomNumberGenerator
    ) -> [Record] {
        nearbyIDs.enumerated().map { index, id in
            let location = randomPoint(within: LocationInfo.metersInMile, of: origin, rng: &rng)
            let stamp = now.addingTimeInterval(-Double(index))
            return Record(
                id: id,
                name: nearbyNames[index % nearbyNames.count],
                description: "Debug record near current location",
                photoID: nil,
                location: location,
                zodiacSign: nearbyZodiacs.randomElement(using: &rng),
                createdAt: stamp,
                updatedAt: stamp,
                metadata: RecordMetadata(
                    timeOfDay: nearbyTimesOfDay.randomElement(using: &rng) ?? .midday,
                    moonPhase: nearbyMoonPhases.randomElement(using: &rng) ?? .fullMoon
                )
            )
        }
    }

    /// Convenience overload for callers that don't supply their own RNG.
    static func nearbyRecords(around origin: LocationInfo) -> [Record] {
        var rng = SystemRandomNumberGenerator()
        return nearbyRecords(around: origin, rng: &rng)
    }

    /// Uniform-disk random sampling — picks a bearing in [0, 2π) and a radius
    /// proportional to √u so the points are evenly distributed by area
    /// rather than concentrated near the center. The 1-mile radius
    /// approximates `radiusMeters / metersPerDegreeLatitude` for the lat
    /// offset; longitude additionally divides by cos(lat) to compensate
    /// for meridian convergence.
    private static func randomPoint(
        within radiusMeters: Double,
        of origin: LocationInfo,
        rng: inout some RandomNumberGenerator
    ) -> LocationInfo {
        let bearing = Double.random(in: 0..<(2 * .pi), using: &rng)
        let radius = radiusMeters * sqrt(Double.random(in: 0..<1, using: &rng))
        let metersPerDegreeLat = 111_000.0
        let dLat = (radius * cos(bearing)) / metersPerDegreeLat
        let dLon = (radius * sin(bearing)) / (metersPerDegreeLat * cos(origin.latitude * .pi / 180))
        return LocationInfo(
            latitude: origin.latitude + dLat,
            longitude: origin.longitude + dLon
        )
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

    #if DEBUG
    /// 78 records — 26 letters × 3 `GuillocheShape` variants — used by the
    /// in-app letter-gallery debug screen to verify each blended-letter SVG
    /// renders and animates in the right direction. Name's first character
    /// drives `VisualAccoutrements.letter`; `guillocheShape` is set explicitly
    /// so we exercise every (letter, shape) cell instead of relying on the
    /// UUID-byte-sum default.
    static var letterGalleryRecords: [Record] {
        let now = Date()
        let metadata = RecordMetadata(timeOfDay: .midday, moonPhase: .fullMoon)
        let shapes = GuillocheShape.allCases
        var result: [Record] = []
        result.reserveCapacity(26 * shapes.count)
        for letterIndex in 0..<26 {
            let scalar = Unicode.Scalar(UInt8(0x41) + UInt8(letterIndex))
            let letter = Character(scalar)
            for (shapeIndex, shape) in shapes.enumerated() {
                let flatIndex = letterIndex * shapes.count + shapeIndex
                let stamp = now.addingTimeInterval(-Double(flatIndex))
                result.append(
                    Record(
                        id: UUID(),
                        name: "\(letter) — \(shape.rawValue.capitalized)",
                        description: "",
                        photoID: nil,
                        location: nil,
                        zodiacSign: .leo,
                        createdAt: stamp,
                        updatedAt: stamp,
                        metadata: metadata,
                        guillocheShape: shape
                    )
                )
            }
        }
        return result
    }
    #endif

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
