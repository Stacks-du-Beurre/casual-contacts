import CoreModels
import DesignSystem
import SwiftUI

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
    public let photoSize: CGSize?

    @Bindable private var blendTuning = CardBlendTuning.shared

    public init(
        record: Record,
        size: CardSize,
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        photo: Image? = nil,
        photoSize: CGSize? = nil
    ) {
        self.record = record
        self.size = size
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
        self.photoSize = photoSize
    }

    public var body: some View {
        return GeometryReader { geo in
            let layout = CardLayout(size: geo.size)
            // Build the backdrop view value once per body evaluation and hand the
            // same struct to the three consumers (card background, name hologram
            // sample, location pill sample) instead of reconstructing it through
            // three separate `@ViewBuilder` closures.
            let sharedBackdrop = backdrop()
            ZStack {
                // Developer toggle (`CardBlendTuning.hideBackdrop`) omits the
                // backdrop from both the rendered card and the text layer's
                // sample closure — useful for isolating chrome/text work.
                if !blendTuning.hideBackdrop {
                    sharedBackdrop
                }

                // Figural ornaments — rendered above the sampled backdrop so the
                // hologram text and frosted location pill don't blur the moon,
                // constellation, or zodiac figure into their chrome.
                ornaments()

                CardTextLayer(
                    record: record,
                    attitude: attitude,
                    layout: layout,
                    coordinateSpaceName: Self.cardCoordinateSpace,
                    backdrop: {
                        if blendTuning.hideBackdrop {
                            Color.clear
                        } else {
                            sharedBackdrop
                        }
                    }
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
    private func backdrop() -> some View {
        // Use `.overlay(alignment:)` to position the constellation at the
        // top-trailing corner of `CardBackdrop`. The previous implementation
        // wrapped the `ZodiacLayer` in `.frame(maxWidth: .infinity, maxHeight:
        // .infinity, alignment: .topTrailing)` to achieve the same positioning,
        // but that infinity-frame propagated an unbounded horizontal ideal up
        // through the `backdrop()` ZStack → through the outer `ZStack` → past
        // the `.frame(width: geo.size.width, height: geo.size.height)` wrapper
        // in some layout contexts (notably fullscreen covers with no upstream
        // horizontal constraint), ballooning the card's internal layout to
        // ~1260pt wide and pushing the chrome overlays hundreds of points
        // off-screen. `.overlay` keeps the positioning semantics without the
        // unbounded ideal-size propagation.
        CardBackdrop(
            record: record,
            attitude: attitude,
            paths: paths,
            photo: photo,
            photoSize: photoSize
        )
        .overlay(alignment: .topTrailing) {
            // Zodiac stars (constellation): 100×90 pinned to the right edge,
            // top inset 37pt. Part of the backdrop so hologram text / frosted
            // pills sample it through the blur.
            if let sign = record.zodiacSign {
                ZodiacLayer(sign: sign, attitude: attitude, variant: .constellation)
                    .frame(width: 100, height: 90)
                    .padding(.top, 37)
                    .accessibilityHidden(true)
            }
        }
    }

    private func ornaments() -> some View {
        // `Color.clear` is flex-flex, so it reliably fills the parent ZStack's
        // bounds — overlays then anchor to known edges without relying on
        // `.padding + .frame(maxWidth/Height: .infinity, alignment:)` proposal
        // propagation, which can silently collapse inside nested ZStacks.
        Color.clear
            .overlay(alignment: .bottomTrailing) {
                // Zodiac figure frame — 35×32 (intrinsic to `HolographicZodiac`),
                // sitting 9pt above the top of the moon phase frame below.
                // Moon top = 14 (bottom) + 56 (height) = 70; zodiac bottom = 70 + 9 = 79.
                // Trailing 54 stacks it directly above the moon column.
                if let sign = record.zodiacSign {
                    HolographicZodiac(sign: sign, attitude: attitude)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 79, trailing: 54))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Moon phase frame: 34×56, bottom-trailing.
                MoonPhaseLayer(phase: record.metadata.moonPhase)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 14, trailing: 54))
            }
    }

    public static func accessibilityLabel(for record: Record) -> String {
        var parts: [String] = [record.name]
        if !record.description.isEmpty { parts.append(record.description) }
        if let label = record.location?.label { parts.append(label) }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Layout helper

/// Carries the live card size so children that need it (pill max-widths,
/// backdrop sampling) can refer to it without reading geometry themselves.
struct CardLayout {
    let size: CGSize
}

struct CardTextLayer<Backdrop: View>: View {
    let record: Record
    let attitude: DeviceAttitude
    let layout: CardLayout
    let coordinateSpaceName: String
    @ViewBuilder let backdrop: () -> Backdrop

    var body: some View {
        // `Color.clear` fills the parent ZStack; overlays anchor to its known
        // bounds so padding reliably pushes content away from each edge.
        Color.clear
            .overlay(alignment: .topLeading) {
                // Top-left: location pill with location glyph + uppercase label.
                // Capped to ~45% of card width so a long address doesn't collide
                // with the date/time block at top-right.
                if let label = record.location?.label, !label.isEmpty {
                    LocationPill(
                        label: label,
                        maxWidth: layout.size.width * 0.45,
                        backdropSize: layout.size,
                        coordinateSpaceName: coordinateSpaceName,
                        attitude: attitude,
                        backdrop: backdrop
                    )
                    .padding(EdgeInsets(top: 14, leading: 5, bottom: 0, trailing: 0))
                }
            }
            .overlay(alignment: .topTrailing) {
                // Top-right: date + time-of-day label, right-aligned two-line block.
                // Equatable so it short-circuits on gyro updates (no attitude dep).
                DateTimeBlock(record: record)
                    .equatable()
                    .padding(EdgeInsets(top: 14, leading: 0, bottom: 0, trailing: 8))
            }
            .overlay(alignment: .bottomLeading) {
                // Bottom-left: name hologram stacked above the description pills.
                VStack(alignment: .leading, spacing: 8) {
                    HologramText(
                        record.name,
                        font: CCDesign.Typography.title,
                        attitude: attitude,
                        backdropSize: layout.size,
                        coordinateSpaceName: coordinateSpaceName,
                        backdrop: backdrop
                    )
                    .fixedSize()

                    if !record.description.isEmpty {
                        DescriptionPills(
                            text: record.description,
                            maxPillWidth: max(0, layout.size.width - 32 - 60)
                        )
                    }
                }
                .padding(EdgeInsets(top: 0, leading: 8, bottom: 14, trailing: 0))
            }
            .overlay(alignment: .bottomTrailing) {
                // Zodiac label sits just above the top of the moon phase frame.
                // Equatable — no attitude dep.
                if let sign = record.zodiacSign {
                    ZodiacLabel(sign: sign)
                        .equatable()
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 77, trailing: 8))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Right-bottom: moon phase label, two lines right-aligned, with a
                // 1pt dot floating 4pt above the label's right edge. Equatable.
                MoonLabelColumn(phase: record.metadata.moonPhase)
                    .equatable()
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 14, trailing: 8))
            }
            .overlay {
                // Right-edge decorative hairlines — no inputs, trivially Equatable.
                RightEdgeHairlines()
                    .equatable()
            }
    }
}

// MARK: - Extracted subviews

private struct LocationPill<Backdrop: View>: View {
    let label: String
    let maxWidth: CGFloat
    let backdropSize: CGSize
    let coordinateSpaceName: String
    let attitude: DeviceAttitude
    @ViewBuilder let backdrop: () -> Backdrop

    var body: some View {
        BackdropBlurPill(
            fill: Color(red: 40 / 255, green: 60 / 255, blue: 85 / 255).opacity(0.1),
            blurRadius: 1.25,
            backdropSize: backdropSize,
            coordinateSpaceName: coordinateSpaceName,
            backdrop: backdrop
        ) {
            ZStack {
                content
                    .blur(radius: 1.25)
                    .offset(
                        x: CGFloat(attitude.roll) * 16,
                        y: CGFloat(attitude.pitch) * 16
                    )
                content
            }
            .clipped()
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(label.split(separator: ", ").enumerated()), id: \.offset) { _, segment in
                    Text(segment.uppercased())
                        .font(CCDesign.Typography.caption1)
                        .tracking(CCDesign.Typography.Tracking.caption1)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Image("LocationPin", bundle: CCDesign.bundle)
                .renderingMode(.template)
                .resizable()
                .frame(width: 12, height: 12)
                .foregroundStyle(CCDesign.Colors.L0)
                .opacity(0.75)
        }
        .frame(height: 24)
        .padding(.horizontal, 12)
    }
}

private struct DateTimeBlock: View, Equatable {
    let record: Record

    // DateFormatter allocation is expensive; share a single instance per format.
    // Sendable as of Swift 6, safe to use across body evaluations.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f
    }()

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(Self.dateFormatter.string(from: record.createdAt))
            Text(timeLine)
        }
        .font(CCDesign.Typography.caption2)
        .foregroundStyle(.white)
        .multilineTextAlignment(.trailing)
    }

    private var timeLine: String {
        let time = Self.timeFormatter.string(from: record.createdAt)
        let label = record.metadata.timeOfDay.rawValue.capitalized
        return "\(label), \(time)"
    }
}

/// 1pt dot + two-line moon phase label. Extracted as an Equatable wrapper so
/// the `.equatable()` short-circuit applies to the full composition, not just
/// the inner label. Inputs depend only on phase — attitude-independent.
private struct MoonLabelColumn: View, Equatable {
    let phase: MoonPhase

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Rectangle()
                .fill(Color.white)
                .frame(width: 1, height: 1)
            MoonLabel(phase: phase)
        }
    }
}

private struct MoonLabel: View, Equatable {
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

    /// Two-word split for a two-line right-aligned caption matching Figma `Cards/Full`.
    private var displayWords: [String] {
        switch phase {
        case .newMoon: return ["New", "Moon"]
        case .waxingCrescent: return ["Waxing", "Crescent"]
        case .firstQuarter: return ["First", "Quarter"]
        case .waxingGibbous: return ["Waxing", "Gibbous"]
        case .fullMoon: return ["Full", "Moon"]
        case .waningGibbous: return ["Waning", "Gibbous"]
        case .thirdQuarter: return ["Third", "Quarter"]
        case .waningCrescent: return ["Waning", "Crescent"]
        }
    }
}

private struct ZodiacLabel: View, Equatable {
    let sign: ZodiacSign

    var body: some View {
        Text(sign.rawValue.capitalized)
            .font(CCDesign.Typography.caption2)
            .foregroundStyle(.white)
    }
}

private struct RightEdgeHairlines: View, Equatable {
    var body: some View {
        Color.clear
            .overlay(alignment: .bottomTrailing) {
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 6, height: 1)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 62, trailing: 8))
            }
            .overlay(alignment: .bottomTrailing) {
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 6, height: 1)
                    .rotationEffect(.degrees(45))
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 8))
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#if DEBUG

    private struct PreviewPathProvider: CardPathProvider {
        func rotationPaths(for _: Character) -> [Path] {
            []
        }

        func blendPaths(
            for _: Character,
            shape _: GuillocheShape,
            density _: CCVisuals.Guilloche.LineDensity
        ) -> [Path] {
            []
        }
    }

    private func previewRecord(
        name: String = "Alona",
        description: String = "Met her at my office last year",
        zodiac: ZodiacSign? = .sagittarius,
        timeOfDay: TimeOfDay = .midday,
        moonPhase: MoonPhase = .fullMoon,
        location: String? = "1200 Treat Ave, San Francisco"
    ) -> Record {
        Record(
            id: UUID(),
            name: name,
            description: description,
            photoID: nil,
            location: location.map {
                LocationInfo(latitude: 37.77, longitude: -122.41, label: $0)
            },
            zodiacSign: zodiac,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: RecordMetadata(timeOfDay: timeOfDay, moonPhase: moonPhase)
        )
    }

    #Preview("Card — full") {
        CardView(
            record: previewRecord(),
            size: .medium,
            attitude: .zero,
            paths: PreviewPathProvider()
        )
        .frame(width: 343, height: 211)
        .padding()
        .background(Color.black)
    }

    #Preview("Card — no location, no description") {
        CardView(
            record: previewRecord(description: "", location: nil),
            size: .medium,
            attitude: .zero,
            paths: PreviewPathProvider()
        )
        .frame(width: 343, height: 211)
        .padding()
        .background(Color.black)
    }

    #Preview("Card — long description") {
        CardView(
            record: previewRecord(
                description: "Met her at an opening in the mission, we talked for hours about jazz"
            ),
            size: .medium,
            attitude: .zero,
            paths: PreviewPathProvider()
        )
        .frame(width: 343, height: 211)
        .padding()
        .background(Color.black)
    }

    #Preview("Card — night, new moon") {
        CardView(
            record: previewRecord(
                zodiac: .leo,
                timeOfDay: .night,
                moonPhase: .newMoon
            ),
            size: .medium,
            attitude: .zero,
            paths: PreviewPathProvider()
        )
        .frame(width: 343, height: 211)
        .padding()
        .background(Color.black)
    }

#endif
