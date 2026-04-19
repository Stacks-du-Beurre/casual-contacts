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
            let layout = CardLayout(size: geo.size)
            ZStack {
                backdrop(accoutrements: accoutrements, density: density, layout: layout)

                CardTextLayer(
                    record: record,
                    layout: layout,
                    coordinateSpaceName: Self.cardCoordinateSpace,
                    backdrop: { backdrop(accoutrements: accoutrements, density: density, layout: layout) }
                )
            }
            // Pin to the geometry reader's bounds so ideal-size propagation from
            // `.fixedSize()` children (name/location pills) can't push the card
            // wider than the caller's frame.
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .coordinateSpace(.named(Self.cardCoordinateSpace))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(for: record))
    }

    private static let cardCoordinateSpace = "CardScene"

    @ViewBuilder
    private func backdrop(
        accoutrements: VisualAccoutrements,
        density: CCVisuals.Guilloche.LineDensity,
        layout: CardLayout
    ) -> some View {
        ZStack {
            GradientLayer(timeOfDay: record.metadata.timeOfDay, attitude: attitude)

            GuillocheRotationLayer(paths: paths.rotationPaths(for: accoutrements.letter))

            // Letter-shaped background silhouette — the single letter outline
            // rotated in 5° steps. Sits between the ambient rotation filigree
            // and the foreground blend letter to create depth.
            BBackgroundSilhouetteLayer(
                paths: GuillocheRotationLayer.swirlPaths(
                    from: paths.rotationPaths(for: accoutrements.letter).first
                )
            )

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

            // Zodiac stars (constellation): 100×90 at right-edge, vertically centered.
            // Figma `Cards/Full` right-column composition — the stars frame the symbol.
            if let sign = record.zodiacSign {
                ZodiacLayer(sign: sign, attitude: attitude, variant: .constellation)
                    .frame(width: layout.x(100), height: layout.y(90))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .accessibilityHidden(true)
            }

            // Zodiac symbol (figure) with holographic luminosity: 35×32 at
            // right:57 bottom:72 — sits inside the stars frame.
            if let sign = record.zodiacSign {
                HolographicZodiac(sign: sign, attitude: attitude)
                    .frame(width: layout.x(35), height: layout.y(32))
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: layout.y(72), trailing: layout.x(57)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }

            // Moon phase glyph: 34×56 at right:58 bottom:7 per Figma `Cards/Full`.
            MoonPhaseLayer(phase: record.metadata.moonPhase)
                .frame(width: layout.x(34), height: layout.y(56))
                .padding(EdgeInsets(top: 0, leading: 0, bottom: layout.y(7), trailing: layout.x(58)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    public static func accessibilityLabel(for record: Record) -> String {
        var parts: [String] = [record.name]
        if !record.description.isEmpty { parts.append(record.description) }
        if let label = record.location?.label { parts.append(label) }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Proportional layout helper

/// Maps Figma's base card dimensions (335×211 `Cards/Full`) to the actual
/// rendered card size so anchors, paddings, and child frames scale with the
/// card. Per CLAUDE.md: "Flexible layout, fixed design — reproduce Figma
/// proportions but breathe across device sizes."
struct CardLayout {
    let size: CGSize

    static let baseWidth: CGFloat = 335
    static let baseHeight: CGFloat = 211

    var xScale: CGFloat { size.width  / Self.baseWidth  }
    var yScale: CGFloat { size.height / Self.baseHeight }

    /// Horizontal Figma pixel value → scaled point value.
    func x(_ px: CGFloat) -> CGFloat { px * xScale }

    /// Vertical Figma pixel value → scaled point value.
    func y(_ px: CGFloat) -> CGFloat { px * yScale }
}

struct CardTextLayer<Backdrop: View>: View {
    let record: Record
    let layout: CardLayout
    let coordinateSpaceName: String
    @ViewBuilder let backdrop: () -> Backdrop

    var body: some View {
        ZStack {
            // Top-left: location pill (backdrop-blur + tint) with location glyph +
            // uppercase label. Capped to ~45% of card width so a long street
            // address doesn't collide with the date/time block at top-right.
            if let label = record.location?.label, !label.isEmpty {
                LocationPill(
                    label: label,
                    maxWidth: layout.size.width * 0.45,
                    backdropSize: layout.size,
                    coordinateSpaceName: coordinateSpaceName,
                    backdrop: backdrop
                )
                .padding(EdgeInsets(top: layout.y(8), leading: layout.x(5), bottom: 0, trailing: 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            // Top-right: date + time-of-day label, right-aligned two-line block.
            DateTimeBlock(record: record)
                .padding(EdgeInsets(top: layout.y(8), leading: 0, bottom: 0, trailing: layout.x(8)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            // Middle-left: name hologram pill, anchored bottom:72 left:8.
            HologramPill(
                backdropSize: layout.size,
                coordinateSpaceName: coordinateSpaceName,
                backdrop: backdrop
            ) {
                HologramText(record.name, font: CCDesign.Typography.title)
                    .padding(.horizontal, 6)
            }
            .fixedSize()
            .padding(EdgeInsets(top: 0, leading: layout.x(8), bottom: layout.y(72), trailing: 0))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            // Lower-left: description pills stack, anchored bottom:8 left:9.
            // maxPillWidth keeps each pill inside the card (minus right-column
            // real estate reserved for zodiac stars + moon).
            if !record.description.isEmpty {
                DescriptionPills(
                    text: record.description,
                    maxPillWidth: max(0, layout.size.width - layout.x(32) - layout.x(60))
                )
                .padding(EdgeInsets(top: 0, leading: layout.x(9), bottom: layout.y(8), trailing: 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            // Right-column zodiac label, anchored below the stars frame.
            // Figma places it at right:8 bottom:82 translate-y-full (i.e. bottom:82
            // minus its own height ≈ 12pt line-height → effective bottom ≈ 70pt).
            if let sign = record.zodiacSign {
                ZodiacLabel(sign: sign)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: layout.y(70), trailing: layout.x(8)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }

            // Right-bottom: moon phase label, two lines right-aligned.
            MoonLabel(phase: record.metadata.moonPhase)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: layout.y(8), trailing: layout.x(8)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            // Right-edge decorative hairlines — Figma Line 1 (horizontal) + Line 2 (rotated).
            // Exact opacity not yet pinned from Figma; using 0.5 as a visible placeholder.
            RightEdgeHairlines(layout: layout)
        }
    }
}

// MARK: - Extracted subviews

private struct LocationPill<Backdrop: View>: View {
    let label: String
    let maxWidth: CGFloat
    let backdropSize: CGSize
    let coordinateSpaceName: String
    @ViewBuilder let backdrop: () -> Backdrop

    var body: some View {
        HologramPill(
            baseFill: Color(red: 40/255, green: 60/255, blue: 85/255).opacity(0.1),
            hologramOpacity: 0,  // backdrop-blur + tint only, no luminosity texture
            backdropSize: backdropSize,
            coordinateSpaceName: coordinateSpaceName,
            backdrop: backdrop
        ) {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                Text(label.uppercased())
                    .font(CCDesign.Typography.caption1)
                    .tracking(CCDesign.Typography.Tracking.caption1)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct DateTimeBlock: View {
    let record: Record

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(dateLine)
            Text(timeLine)
        }
        .font(CCDesign.Typography.caption2)
        .foregroundStyle(.white)
        .multilineTextAlignment(.trailing)
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: record.createdAt)
    }

    private var timeLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        let time = formatter.string(from: record.createdAt)
        let label = record.metadata.timeOfDay.rawValue.capitalized
        return "\(label), \(time)"
    }
}

private struct MoonLabel: View {
    let phase: MoonPhase

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(displayWords.enumerated()), id: \.offset) { _, word in
                Text(word)
            }
        }
        .font(CCDesign.Typography.caption2)
        .foregroundStyle(.white)
        .multilineTextAlignment(.trailing)
    }

    // Two-word split for a two-line right-aligned caption matching Figma `Cards/Full`.
    private var displayWords: [String] {
        switch phase {
        case .newMoon:         return ["New", "Moon"]
        case .waxingCrescent:  return ["Waxing", "Crescent"]
        case .firstQuarter:    return ["First", "Quarter"]
        case .waxingGibbous:   return ["Waxing", "Gibbous"]
        case .fullMoon:        return ["Full", "Moon"]
        case .waningGibbous:   return ["Waning", "Gibbous"]
        case .thirdQuarter:    return ["Third", "Quarter"]
        case .waningCrescent:  return ["Waning", "Crescent"]
        }
    }
}

private struct ZodiacLabel: View {
    let sign: ZodiacSign

    var body: some View {
        Text(sign.rawValue.capitalized)
            .font(CCDesign.Typography.caption2)
            .foregroundStyle(.white)
    }
}

private struct RightEdgeHairlines: View {
    let layout: CardLayout

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: layout.x(6), height: 1)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: layout.y(62), trailing: layout.x(8)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: layout.x(6), height: 1)
                .rotationEffect(.degrees(45))
                .padding(EdgeInsets(top: 0, leading: 0, bottom: layout.y(34), trailing: layout.x(8)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .accessibilityHidden(true)
    }
}
