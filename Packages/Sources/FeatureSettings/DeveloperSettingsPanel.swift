import SwiftUI
import CoreModels
import DesignSystem
import Visuals

struct DeveloperSettingsPanel: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    /// Closures injected by the host so the panel can stay in
    /// `FeatureSettings` (which has no `Storage` dependency). The
    /// `AppFeature` host wires these to a `RecordStore` + the
    /// `DebugRecordSeeder` fixtures. Default to no-ops so the panel
    /// previews and host-tests cleanly without seeding side effects.
    let onAddDebugRecords: () -> Void
    let onAddNearbyDebugRecords: () -> Void
    let onRemoveDebugRecords: () -> Void
    /// DEBUG: opens the 78-card letter-gallery diagnostic. Default no-op
    /// keeps previews and host-tests compiling without an explicit hook.
    let onOpenLetterGallery: () -> Void

    init(
        onAddDebugRecords: @escaping () -> Void = {},
        onAddNearbyDebugRecords: @escaping () -> Void = {},
        onRemoveDebugRecords: @escaping () -> Void = {},
        onOpenLetterGallery: @escaping () -> Void = {}
    ) {
        self.onAddDebugRecords = onAddDebugRecords
        self.onAddNearbyDebugRecords = onAddNearbyDebugRecords
        self.onRemoveDebugRecords = onRemoveDebugRecords
        self.onOpenLetterGallery = onOpenLetterGallery
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            DeveloperSettingsContent(
                onAddDebugRecords: onAddDebugRecords,
                onAddNearbyDebugRecords: onAddNearbyDebugRecords,
                onRemoveDebugRecords: onRemoveDebugRecords,
                onOpenLetterGallery: onOpenLetterGallery
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SettingsPalette.sheetBackground(scheme))
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private var header: some View {
        ZStack {
            FeatureSettingsLocalization.text("Developer", locale: locale)
                .font(CCDesign.Typography.headline)
                .tracking(CCDesign.Typography.Tracking.headline)
                .textCase(.uppercase)
                .foregroundStyle(SettingsPalette.label(scheme))
                .accessibilityAddTraits(.isHeader)

            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SettingsPalette.icon(scheme))
                        .frame(width: 44, height: 43)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(FeatureSettingsLocalization.text("Back", locale: locale))
                Spacer()
            }
        }
        .frame(height: 56)
    }
}

public struct InListDeveloperSettingsPanel: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale

    private let onClose: () -> Void
    private let onAddDebugRecords: () -> Void
    private let onAddNearbyDebugRecords: () -> Void
    private let onRemoveDebugRecords: () -> Void
    private let onOpenLetterGallery: () -> Void

    public init(
        onClose: @escaping () -> Void,
        onAddDebugRecords: @escaping () -> Void = {},
        onAddNearbyDebugRecords: @escaping () -> Void = {},
        onRemoveDebugRecords: @escaping () -> Void = {},
        onOpenLetterGallery: @escaping () -> Void = {}
    ) {
        self.onClose = onClose
        self.onAddDebugRecords = onAddDebugRecords
        self.onAddNearbyDebugRecords = onAddNearbyDebugRecords
        self.onRemoveDebugRecords = onRemoveDebugRecords
        self.onOpenLetterGallery = onOpenLetterGallery
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            DeveloperSettingsContent(
                onAddDebugRecords: onAddDebugRecords,
                onAddNearbyDebugRecords: onAddNearbyDebugRecords,
                onRemoveDebugRecords: onRemoveDebugRecords,
                onOpenLetterGallery: onOpenLetterGallery,
                bottomPadding: 16
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .background(SettingsPalette.sheetBackground(scheme))
        .overlay(alignment: .top) {
            SettingsPalette.border(scheme)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        ZStack {
            FeatureSettingsLocalization.text("Developer", locale: locale)
                .font(CCDesign.Typography.headline)
                .tracking(CCDesign.Typography.Tracking.headline)
                .textCase(.uppercase)
                .foregroundStyle(SettingsPalette.label(scheme))
                .accessibilityAddTraits(.isHeader)

            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(SettingsPalette.icon(scheme))
                        .frame(width: 44, height: 43)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(FeatureSettingsLocalization.text("Close in-list developer settings", locale: locale))
            }
        }
        .frame(height: 48)
    }
}

private struct DeveloperSettingsContent: View {

    @Bindable private var tuning = HologramTuning.shared
    @Bindable private var gradientTuning = EmptyStateGradientTuning.shared
    @Bindable private var cardBlendTuning = CardBlendTuning.shared
    @Bindable private var zodiacTuning = ZodiacHologramTuning.shared
    @Bindable private var rotationTuning = GuillocheRotationTuning.shared
    @Bindable private var photoFocusTuning = PhotoFocusTuning.shared
    @Bindable private var mediumCardTuning = MediumCardSizeTuning.shared
    @Bindable private var elementDepthTuning = CardElementDepthTuning.shared
    @Bindable private var motionTuning = MotionTuning.shared
    @Bindable private var cardAnimationDiagnostics = CardAnimationDiagnostics.shared

    let onAddDebugRecords: () -> Void
    let onAddNearbyDebugRecords: () -> Void
    let onRemoveDebugRecords: () -> Void
    let onOpenLetterGallery: () -> Void
    var bottomPadding: CGFloat = 24

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                motionGroup
                toggleGroup
                diagnosticsGroup
                opacityGroup
                gradientGroup
                elementDepthGroup
                zodiacGroup
                mediumCardGroup
                debugDataGroup
                resetGroup
            }
            .padding(.top, 8)
            .padding(.bottom, bottomPadding)
        }
    }

    private var toggleGroup: some View {
        SettingsGroup(title: "Card Backdrop") {
            ToggleRow(
                label: "Hide card backdrop",
                isOn: $cardBlendTuning.hideBackdrop
            )
            SettingsDivider()
            ToggleRow(
                label: "Reverse depth order",
                isOn: $cardBlendTuning.reverseDepthOrder
            )
            SettingsDivider()
            ToggleRow(
                label: "Reverse motion direction",
                isOn: $cardBlendTuning.reverseMotionDirection
            )
            SettingsDivider()
            ToggleRow(
                label: "Move rotation guilloche instead of rotate",
                isOn: $cardBlendTuning.rotationGuillocheMovesInsteadOfRotates
            )
        }
    }

    private var diagnosticsGroup: some View {
        SettingsGroup(title: "Diagnostics") {
            ToggleRow(
                label: "Show card animation counter",
                isOn: $cardAnimationDiagnostics.showsOverlay
            )
        }
    }

    private var opacityGroup: some View {
        SettingsGroup(title: "Hologram Opacity") {
            SliderRow(
                label: "Backdrop blur",
                value: $tuning.backdropBlurOpacity,
                range: 0...1,
                format: .percent
            )
            SettingsDivider()
            SliderRow(
                label: "White fill",
                value: $tuning.whiteFillOpacity,
                range: 0...1,
                format: .percent
            )
            SettingsDivider()
            SliderRow(
                label: "Lighten hologram",
                value: $tuning.lightenOpacity,
                range: 0...1,
                format: .percent
            )
            SettingsDivider()
            SliderRow(
                label: "Luminosity hologram",
                value: $tuning.luminosityOpacity,
                range: 0...1,
                format: .percent
            )
        }
    }

    private var motionGroup: some View {
        SettingsGroup(title: "Motion") {
            SliderRow(
                label: "Pipeline full-scale (deg)",
                value: $motionTuning.relativeFullScaleDegrees,
                range: 10...180,
                format: .decimal
            )
            SettingsDivider()
            SliderRow(
                label: "Zero reset timer (s)",
                value: $motionTuning.zeroPointSettleDuration,
                range: MotionTuning.Defaults.zeroPointSettleDurationMin...MotionTuning.Defaults.zeroPointSettleDurationMax,
                format: .decimal,
                tick: SliderRow.Tick(value: MotionTuning.Defaults.zeroPointSettleDuration, label: "2s")
            )
            SettingsDivider()
            SliderRow(
                label: "Hologram translation X",
                value: $tuning.translationScaleX,
                range: 0...180,
                format: .decimal
            )
            SettingsDivider()
            SliderRow(
                label: "Hologram translation Y",
                value: $tuning.translationScaleY,
                range: 0...180,
                format: .decimal
            )
            SettingsDivider()
            SliderRow(
                label: "Hologram rotation (deg)",
                value: $tuning.rotationDegrees,
                range: 0...360,
                format: .decimal
            )
            SettingsDivider()
            SliderRow(
                label: "Save-button gradient gain",
                value: $motionTuning.saveButtonGradientGain,
                range: 0.5...5.0,
                format: .decimal
            )
            SettingsDivider()
            SliderRow(
                label: "Card-blend depth",
                value: $cardBlendTuning.depthScale,
                range: 0...20,
                format: .decimal
            )
        }
    }

    private var gradientGroup: some View {
        SettingsGroup(title: "Gradient & Filigree") {
            SliderRow(
                label: "Empty-state edge reach",
                value: $gradientTuning.edgeReach,
                range: 0...1,
                format: .percent
            )
            SettingsDivider()
            SliderRow(
                label: "Empty-state filigree spin (degrees)",
                value: $rotationTuning.emptyStateRotationDegrees,
                range: 0...360,
                format: .decimal
            )
            SettingsDivider()
            SliderRow(
                label: "Card filigree spin (degrees)",
                value: $rotationTuning.cardRotationDegrees,
                range: 0...360,
                format: .decimal
            )
            SettingsDivider()
            SliderRow(
                label: "Empty-state filigree opacity",
                value: $rotationTuning.emptyStateOpacity,
                range: 0...GuillocheRotationTuning.Defaults.opacityMax,
                format: .percent
            )
            SettingsDivider()
            SliderRow(
                label: "Card filigree opacity",
                value: $rotationTuning.cardOpacity,
                range: 0...GuillocheRotationTuning.Defaults.opacityMax,
                format: .percent
            )
        }
    }

    private var elementDepthGroup: some View {
        SettingsGroup(title: "Card Element Depth") {
            SliderRow(
                label: "Depth perspective amount",
                value: $elementDepthTuning.perspectiveAmount,
                range: CardElementDepthTuning.Defaults.perspectiveAmountMin...CardElementDepthTuning.Defaults.perspectiveAmountMax,
                format: .decimal,
                tick: SliderRow.Tick(value: CardElementDepthTuning.Defaults.perspectiveAmount, label: "1")
            )
            SettingsDivider()
            IntSliderRow(
                label: "Moon phase depth layer",
                value: $elementDepthTuning.moonPhaseLayer,
                range: CardElementDepthTuning.layerRange
            )
            SettingsDivider()
            IntSliderRow(
                label: "Zodiac glyph depth layer",
                value: $elementDepthTuning.zodiacGlyphLayer,
                range: CardElementDepthTuning.layerRange
            )
            SettingsDivider()
            IntSliderRow(
                label: "Constellation depth layer",
                value: $elementDepthTuning.zodiacConstellationLayer,
                range: CardElementDepthTuning.layerRange
            )
        }
    }

    private var zodiacGroup: some View {
        SettingsGroup(title: "Zodiac & Photo") {
            SliderRow(
                label: "Zodiac rotation (degrees)",
                value: $zodiacTuning.rotationDegrees,
                range: 0...360,
                format: .decimal
            )
            SettingsDivider()
            SliderRow(
                label: "Photo face zoom",
                value: $photoFocusTuning.faceZoom,
                range: 0...1,
                format: .percent
            )
            SettingsDivider()
            SliderRow(
                label: "Photo opacity",
                value: $photoFocusTuning.opacity,
                range: 0...1,
                format: .percent
            )
        }
    }

    private var mediumCardGroup: some View {
        SettingsGroup(title: "Medium Card") {
            SliderRow(
                label: "Aspect ratio (height : width)",
                value: $mediumCardTuning.aspectRatio,
                range: MediumCardSizeTuning.Defaults.minAspectRatio ... MediumCardSizeTuning.Defaults.maxAspectRatio,
                format: .ratio,
                tick: SliderRow.Tick(value: 1.0, label: "1:1")
            )
        }
    }

    private var debugDataGroup: some View {
        SettingsGroup(title: "Debug Data") {
            SettingsRow(label: "Add debug records", onTap: onAddDebugRecords) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 44, height: 43)
                    .accessibilityHidden(true)
            }
            SettingsDivider()
            SettingsRow(label: "Add 4 nearby records", onTap: onAddNearbyDebugRecords) {
                Image(systemName: "location.circle")
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 44, height: 43)
                    .accessibilityHidden(true)
            }
            SettingsDivider()
            SettingsRow(label: "Remove debug records", onTap: onRemoveDebugRecords) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 44, height: 43)
                    .accessibilityHidden(true)
            }
            SettingsDivider()
            SettingsRow(label: "Letter gallery (78 cards)", onTap: onOpenLetterGallery) {
                Image(systemName: "textformat.abc")
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 44, height: 43)
                    .accessibilityHidden(true)
            }
        }
    }

    private var resetGroup: some View {
        SettingsGroup(title: "Reset") {
            SettingsRow(label: "Reset to defaults", onTap: {
                tuning.reset()
                gradientTuning.reset()
                cardBlendTuning.reset()
                zodiacTuning.reset()
                rotationTuning.reset()
                photoFocusTuning.reset()
                mediumCardTuning.reset()
                motionTuning.reset()
                cardAnimationDiagnostics.reset()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 44, height: 43)
                    .accessibilityHidden(true)
            }
        }
    }
}

struct ToggleRow: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            FeatureSettingsLocalization.text(label, locale: locale)
                .font(.custom("CormorantInfant-SemiBold", size: 18, relativeTo: .body))
                .tracking(CCDesign.Typography.Tracking.description)
                .foregroundStyle(SettingsPalette.label(scheme))
        }
        .tint(SettingsPalette.label(scheme))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct SliderRow: View {

    enum Format { case percent, decimal, ratio }

    struct Tick {
        let value: Double
        let label: String
    }

    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: Format
    var tick: Tick? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                FeatureSettingsLocalization.text(label, locale: locale)
                    .font(.custom("CormorantInfant-SemiBold", size: 18, relativeTo: .body))
                    .tracking(CCDesign.Typography.Tracking.description)
                    .foregroundStyle(SettingsPalette.label(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(valueText)
                    .font(.custom("CormorantInfant-SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(SettingsPalette.icon(scheme))
                    .monospacedDigit()
            }
            Slider(value: $value, in: range)
                .tint(SettingsPalette.label(scheme))
                .overlay(alignment: .leading) {
                    if let tick = tick {
                        tickOverlay(tick)
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func tickOverlay(_ tick: Tick) -> some View {
        // Slider thumb is 28pt wide; its center travels from `thumbInset` to
        // (trackWidth - thumbInset) so the tick aligns with where the thumb
        // would actually sit at `tick.value`.
        let thumbInset: CGFloat = 14
        let normalized = (tick.value - range.lowerBound) / (range.upperBound - range.lowerBound)

        return GeometryReader { proxy in
            let usable = max(0, proxy.size.width - thumbInset * 2)
            let x = thumbInset + usable * CGFloat(normalized)
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(SettingsPalette.icon(scheme))
                    .frame(width: 1, height: 8)
                    .offset(x: x - 0.5, y: -10)
                Text(tick.label)
                    .font(.custom("CormorantInfant-SemiBold", size: 11, relativeTo: .caption))
                    .foregroundStyle(SettingsPalette.icon(scheme))
                    .fixedSize()
                    .offset(x: x - 12, y: -24)
            }
        }
        .allowsHitTesting(false)
    }

    private var valueText: String {
        switch format {
        case .percent:
            return "\(Int((value * 100).rounded()))%"
        case .decimal:
            return String(format: "%.1f", value)
        case .ratio:
            return String(format: "%.2f:1", value)
        }
    }
}

/// Stepped slider over an `Int` range. Uses `Slider`'s built-in `step:` so the
/// thumb snaps to whole-number positions — appropriate for discrete choices
/// like depth-layer indices.
struct IntSliderRow: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                FeatureSettingsLocalization.text(label, locale: locale)
                    .font(.custom("CormorantInfant-SemiBold", size: 18, relativeTo: .body))
                    .tracking(CCDesign.Typography.Tracking.description)
                    .foregroundStyle(SettingsPalette.label(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: "\(value)")
                    .font(.custom("CormorantInfant-SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(SettingsPalette.icon(scheme))
                    .monospacedDigit()
            }
            Slider(
                value: doubleBinding,
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .tint(SettingsPalette.label(scheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var doubleBinding: Binding<Double> {
        Binding(
            get: { Double(value) },
            set: { value = Int($0.rounded()) }
        )
    }
}
