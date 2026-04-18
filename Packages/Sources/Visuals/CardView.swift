import SwiftUI
import CoreModels
import DesignSystem

public protocol CardPathProvider: Sendable {
    func rotationPaths(for letter: Character) -> [Path]
    func blendPaths(for letter: Character, shape: GuillocheShape, density: CCVisuals.Guilloche.LineDensity) -> [Path]
}

public struct CardView: View {

    public let record: Record
    public let size: CardSize
    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let photo: Image?

    public init(
        record: Record,
        size: CardSize,
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        photo: Image? = nil
    ) {
        self.record = record
        self.size = size
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
    }

    public var body: some View {
        let accoutrements = record.accoutrements
        let density: CCVisuals.Guilloche.LineDensity = size == .small ? .preview : .cards

        return ZStack {
            // 1. Gradient base + transfusion
            GradientLayer(timeOfDay: record.metadata.timeOfDay, attitude: attitude)

            // 3. Rotation background
            GuillocheRotationLayer(paths: paths.rotationPaths(for: accoutrements.letter))

            // 4. Photo or letter-blend
            if let photo {
                PhotoLayer(image: photo, style: .card)
            } else {
                GuillocheBlendLayer(
                    paths: paths.blendPaths(
                        for: accoutrements.letter,
                        shape: accoutrements.guillocheShape,
                        density: density
                    ),
                    density: density,
                    attitude: attitude
                )
            }

            // 5. Zodiac (if set)
            if let sign = record.zodiacSign {
                HolographicZodiac(sign: sign, attitude: attitude)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
            }

            // 6. Moon phase
            MoonPhaseLayer(phase: record.metadata.moonPhase)
                .frame(width: 24, height: 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(8)

            // 7. Card text (name + description + location + date)
            CardTextLayer(record: record, attitude: attitude, size: size)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(for: record))
    }

    /// Build a single VoiceOver announcement from the record's public fields.
    /// Mirrors `SmallCardListItem.accessibilityLabel(for:)` so list cells and cards
    /// say the same thing.
    public static func accessibilityLabel(for record: Record) -> String {
        var parts: [String] = [record.name]
        if !record.description.isEmpty { parts.append(record.description) }
        if let label = record.location?.label { parts.append(label) }
        return parts.joined(separator: ". ")
    }
}

struct CardTextLayer: View {
    let record: Record
    let attitude: DeviceAttitude
    let size: CardSize

    var body: some View {
        VStack(alignment: .leading) {
            HolographicText(text: record.name, attitude: attitude)
            if !record.description.isEmpty {
                Text(record.description)
                    .font(CCDesign.Typography.descriptionSmall)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
            }
            Spacer()
            if let location = record.location?.label {
                HolographicLocation(address: location, attitude: attitude)
            }
        }
        .padding()
    }
}
