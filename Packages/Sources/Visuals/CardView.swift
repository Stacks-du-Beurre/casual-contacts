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
    private let configuredContentInsets: EdgeInsets
    private let configuredExpansionProgress: CGFloat
    @Environment(\.cardExpansionLayout) private var expansionLayout
    public var contentInsets: EdgeInsets { expansionLayout?.insets ?? configuredContentInsets }
    public var expansionProgress: CGFloat { expansionLayout?.progress ?? configuredExpansionProgress }

    @Bindable private var blendTuning = CardBlendTuning.shared
    @Bindable private var depthTuning = CardElementDepthTuning.shared
    @Environment(\.windowSceneProjection) private var windowScene
    @Environment(\.windowCardFrame) private var cardFrame

    public init(
        record: Record,
        size: CardSize,
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        photo: Image? = nil,
        photoSize: CGSize? = nil,
        contentInsets: EdgeInsets = EdgeInsets(),
        expansionProgress: CGFloat = 1
    ) {
        self.record = record
        self.size = size
        self.attitude = attitude
        self.paths = paths
        self.photo = photo
        self.photoSize = photoSize
        self.configuredContentInsets = contentInsets
        self.configuredExpansionProgress = expansionProgress
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
                if size != .large {
                    ornaments().padding(contentInsets)
                } else {
                    fullScreenIdentity(layout: layout, backdrop: sharedBackdrop)
                        .opacity(expansionProgress)
                }

                if size != .large || expansionProgress < 1 {
                CardTextLayer(
                    record: record,
                    size: .medium,
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
                .padding(contentInsets)
                .opacity(size == .large ? 1 - expansionProgress : 1)
                }
            }
            // Pin to the geometry reader's bounds so ideal-size propagation from
            // `.fixedSize()` children (name/location pills) can't push the card
            // wider than the caller's frame.
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .coordinateSpace(.named(Self.cardCoordinateSpace))
            .environment(\.windowCardFrame, cardFrame ?? geo.frame(in: .global))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityLabel(for: record))
    }

    private static let cardCoordinateSpace = "CardScene"

    private func fullScreenIdentity<Backdrop: View>(layout: CardLayout, backdrop: Backdrop) -> some View {
        let accoutrements = record.accoutrements
        let blendPaths = paths.blendPaths(for: accoutrements.letter,
                                         shape: accoutrements.guillocheShape,
                                         density: .cards)
        let reverseOrder = windowScene?.reverseGuillocheDepthOrder ?? blendTuning.reverseDepthOrder
        let deepestPath = reverseOrder ? blendPaths.first : blendPaths.last
        let bounds = deepestPath?.boundingRect ?? CGRect(x: 0, y: 0, width: 184, height: 160)

        // Anchor to the deepest path's unprojected (zero-point) edges. Text
        // stays on the screen surface while the artwork moves behind it.
        return FullScreenIdentityLayout(pathBounds: bounds, contentInsets: contentInsets) {
                HologramText(
                    record.name,
                    font: .custom("CormorantSC-SemiBold", size: 48, relativeTo: .largeTitle),
                    attitude: attitude,
                    backdropSize: layout.size,
                    coordinateSpaceName: Self.cardCoordinateSpace,
                    backdrop: { backdrop }
                )
                .fixedSize(horizontal: false, vertical: true)

                if !record.description.isEmpty {
                    Text(record.description)
                        .font(CCDesign.Typography.description)
                        .tracking(CCDesign.Typography.Tracking.description)
                        .foregroundStyle(CCDesign.Colors.L0)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.15))
                        .overlay(Rectangle().stroke(.white.opacity(0.45), lineWidth: 1))

                } else {
                    Color.clear.frame(height: 0)
                }
                CardTextLayer(record: record, size: .large, attitude: attitude,
                              layout: layout, coordinateSpaceName: Self.cardCoordinateSpace,
                              backdrop: { backdrop })
                if let sign = record.zodiacSign {
                    ZodiacLayer(sign: sign, attitude: attitude, variant: .constellation, parallax: false)
                        .frame(width: 200, height: 180)
                        .offset(depthOffset(layer: depthTuning.zodiacConstellationLayer))
                        .windowDepth(0.25)
                        .accessibilityHidden(true)
                } else {
                    Color.clear.frame(width: 200, height: 180)
                }
            }
            .frame(width: layout.size.width, height: layout.size.height)
    }

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
            // pills sample it through the blur. `parallax: false` cedes motion
            // control to the depth-layer offset applied below.
            if size != .large, let sign = record.zodiacSign {
                ZodiacLayer(sign: sign, attitude: attitude, variant: .constellation, parallax: false)
                    .frame(width: 100, height: 90)
                    .padding(.top, 37)
                    .offset(depthOffset(layer: depthTuning.zodiacConstellationLayer))
                    .windowDepth(0.25)
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
                        .offset(depthOffset(layer: depthTuning.zodiacGlyphLayer))
                        .windowDepth(0.12)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Moon phase frame: 34×56, bottom-trailing.
                MoonPhaseLayer(phase: record.metadata.moonPhase)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 14, trailing: 54))
                    .offset(depthOffset(layer: depthTuning.moonPhaseLayer))
                    .windowDepth(0.12)
            }
    }

    /// Depth-layer translation matching the card's blend stack physics.
    private func depthOffset(layer: Int) -> CGSize {
        if windowScene != nil { return .zero }
        return GuillocheBlendLayer.depthOffset(
            layer: layer,
            attitude: attitude,
            depthScale: blendTuning.depthScale,
            maxLayer: CardElementDepthTuning.layerRange.upperBound,
            reverseDepthOrder: blendTuning.reverseDepthOrder,
            reverseMotionDirection: blendTuning.reverseMotionDirection,
            perspectiveAmount: depthTuning.perspectiveAmount
        )
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
    @Environment(\.locale) private var locale

    let record: Record
    var size: CardSize = .medium
    let attitude: DeviceAttitude
    let layout: CardLayout
    let coordinateSpaceName: String
    @ViewBuilder let backdrop: () -> Backdrop

    var body: some View {
        if size == .large {
            fullScreenContent
        } else {
            compactContent
        }
    }

    private var fullScreenContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 20) {
                if let sign = record.zodiacSign {
                    HStack(spacing: 10) {
                        HolographicZodiac(sign: sign, attitude: attitude, sizeScale: 1.5)
                            .windowDepth(0.12)
                        ZodiacLabel(sign: sign, locale: locale).equatable()
                    }
                }
                Spacer(minLength: 8)
                HStack(spacing: 10) {
                    MoonPhaseLayer(phase: record.metadata.moonPhase, sizeScale: 1.5)
                        .windowDepth(0.12)
                    MoonLabel(phase: record.metadata.moonPhase, locale: locale).equatable()
                }
            }

            VStack(spacing: 16) {
                Rectangle().fill(.white.opacity(0.3)).frame(height: 1)
                HStack(alignment: .top, spacing: 16) {
                    if let label = record.location?.label, !label.isEmpty {
                        LocationPill(
                            label: label,
                            maxWidth: max(0, (layout.size.width - 64) / 2),
                            backdropSize: layout.size,
                            coordinateSpaceName: coordinateSpaceName,
                            attitude: attitude,
                            backdrop: backdrop
                        )
                    }
                    Spacer(minLength: 0)
                    DateTimeBlock(record: record, locale: locale).equatable()
                }
            }
        }
    }

    private var compactContent: some View {
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
                DateTimeBlock(record: record, locale: locale)
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
                    .frame(
                        maxWidth: max(0, layout.size.width - 32 - 60),
                        alignment: .leading
                    )
                    .fixedSize(horizontal: false, vertical: true)

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
                    ZodiacLabel(sign: sign, locale: locale)
                        .equatable()
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 77, trailing: 8))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Right-bottom: moon phase label, two lines right-aligned, with a
                // 1pt dot floating 4pt above the label's right edge. Equatable.
                MoonLabelColumn(phase: record.metadata.moonPhase, locale: locale)
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

    @Bindable private var blendTuning = CardBlendTuning.shared

    var body: some View {
        let direction = CGFloat(blendTuning.motionDirectionMultiplier)
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
                        x: direction * CGFloat(attitude.roll) * 16,
                        y: direction * CGFloat(attitude.pitch) * 16
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
    let locale: Locale

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(Self.formattedDate(record.createdAt))
            Text(timeLine)
        }
        .font(CCDesign.Typography.caption2)
        .foregroundStyle(.white)
        .multilineTextAlignment(.trailing)
    }

    private var timeLine: String {
        LocalizedDateDisplayFormatter.formattedTimeLine(
            record.createdAt,
            timeOfDay: record.metadata.timeOfDay,
            labelLocale: locale,
            timeOfDayDisplayName: VisualsLocalization.timeOfDayDisplayName
        )
    }

    private static func formattedDate(_ date: Date) -> String {
        LocalizedDateDisplayFormatter.formattedDate(date)
    }
}

/// 1pt dot + two-line moon phase label. Extracted as an Equatable wrapper so
/// the `.equatable()` short-circuit applies to the full composition, not just
/// the inner label. Inputs depend only on phase — attitude-independent.
private struct MoonLabelColumn: View, Equatable {
    let phase: MoonPhase
    let locale: Locale

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Rectangle()
                .fill(Color.white)
                .frame(width: 1, height: 1)
            MoonLabel(phase: phase, locale: locale)
        }
    }
}

private struct MoonLabel: View, Equatable {
    let phase: MoonPhase
    let locale: Locale

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
        VisualsLocalization.moonPhaseDisplayName(phase, locale: locale)
            .split(separator: " ")
            .map(String.init)
    }
}

private struct ZodiacLabel: View, Equatable {
    let sign: ZodiacSign
    let locale: Locale

    var body: some View {
        Text(VisualsLocalization.zodiacDisplayName(sign, locale: locale))
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

/// Centers the labels in the gaps between neighboring zero-point edges.
/// The footer is measured in this layout pass, without per-frame state updates.
private struct FullScreenIdentityLayout: Layout {
    let pathBounds: CGRect
    let contentInsets: EdgeInsets

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 4 else { return }
        let width = max(0, bounds.width - contentInsets.leading - contentInsets.trailing)
        let labelProposal = ProposedViewSize(width: width, height: nil)
        let x = bounds.minX + contentInsets.leading
        let top = bounds.midY - 80 + pathBounds.minY
        let bottom = bounds.midY - 80 + pathBounds.maxY
        let footerHeight = subviews[2].sizeThatFits(labelProposal).height
        let footerBottom = bounds.maxY - contentInsets.bottom
        let footerTop = footerBottom - footerHeight
        subviews[2].place(at: CGPoint(x: x, y: footerBottom), anchor: .bottomLeading,
                          proposal: labelProposal)
        let nameCenterY = (bounds.minY + contentInsets.top + top) / 2
        subviews[3].place(at: CGPoint(x: bounds.maxX, y: nameCenterY),
                          anchor: .trailing, proposal: ProposedViewSize(width: 200, height: 180))
        subviews[0].place(at: CGPoint(x: x, y: nameCenterY),
                          anchor: .leading, proposal: labelProposal)
        subviews[1].place(at: CGPoint(x: x, y: (bottom + footerTop) / 2),
                          anchor: .leading, proposal: labelProposal)
    }
}

private struct CardExpansionLayout {
    let progress: CGFloat
    let insets: EdgeInsets
}

private struct CardExpansionLayoutKey: EnvironmentKey {
    static let defaultValue: CardExpansionLayout? = nil
}

private extension EnvironmentValues {
    var cardExpansionLayout: CardExpansionLayout? {
        get { self[CardExpansionLayoutKey.self] }
        set { self[CardExpansionLayoutKey.self] = newValue }
    }
}

public extension View {
    func cardExpansionLayout(progress: CGFloat, insets: EdgeInsets) -> some View {
        environment(\.cardExpansionLayout, CardExpansionLayout(progress: progress, insets: insets))
    }
}
