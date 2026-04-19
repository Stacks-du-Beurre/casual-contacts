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
        // Per DESIGN.md §1.3: list-row, medium, and large cards all use .cards (3 shapes +
        // 15 lines). .preview (1 shape + 7 lines) is reserved for the Recommended Section
        // (deferred to v1.1+), which will have its own component.
        let density: CCVisuals.Guilloche.LineDensity = .cards

        return GeometryReader { geo in
            ZStack {
                backdrop(accoutrements: accoutrements, density: density)

                CardTextLayer(
                    record: record,
                    size: size,
                    attitude: attitude,
                    backdropSize: geo.size,
                    coordinateSpaceName: Self.cardCoordinateSpace,
                    backdrop: { backdrop(accoutrements: accoutrements, density: density) }
                )
            }
            .coordinateSpace(.named(Self.cardCoordinateSpace))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(for: record))
    }

    private static let cardCoordinateSpace = "CardScene"

    @ViewBuilder
    private func backdrop(
        accoutrements: VisualAccoutrements,
        density: CCVisuals.Guilloche.LineDensity
    ) -> some View {
        ZStack {
            GradientLayer(timeOfDay: record.metadata.timeOfDay, attitude: attitude)

            GuillocheRotationLayer(paths: paths.rotationPaths(for: accoutrements.letter))

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

            if let sign = record.zodiacSign {
                HolographicZodiac(sign: sign, attitude: attitude)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
            }

            MoonPhaseLayer(phase: record.metadata.moonPhase)
                .frame(width: 24, height: 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(8)
        }
    }

    public static func accessibilityLabel(for record: Record) -> String {
        var parts: [String] = [record.name]
        if !record.description.isEmpty { parts.append(record.description) }
        if let label = record.location?.label { parts.append(label) }
        return parts.joined(separator: ". ")
    }
}

struct CardTextLayer<Backdrop: View>: View {
    let record: Record
    let size: CardSize
    let attitude: DeviceAttitude
    let backdropSize: CGSize
    let coordinateSpaceName: String
    @ViewBuilder let backdrop: () -> Backdrop

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                HologramText(
                    record.name,
                    font: CCDesign.Typography.title,
                    attitude: attitude,
                    backdropSize: backdropSize,
                    coordinateSpaceName: coordinateSpaceName,
                    backdrop: backdrop
                )
                Spacer(minLength: 0)
            }

            if !record.description.isEmpty {
                DescriptionPills(
                    text: record.description,
                    maxPillWidth: max(0, backdropSize.width - 32 - 60)
                )
            }
            Spacer()
            if let location = record.location?.label {
                Text(location)
                    .font(CCDesign.Typography.caption1)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
            }
        }
        .padding()
    }
}
