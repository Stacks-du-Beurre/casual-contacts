import SwiftUI
import DesignSystem
import Visuals

struct DeveloperSettingsPanel: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @Bindable private var tuning = HologramTuning.shared
    @Bindable private var gradientTuning = EmptyStateGradientTuning.shared
    @Bindable private var cardBlendTuning = CardBlendTuning.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 24) {
                    opacityGroup
                    motionGroup
                    gradientGroup
                    resetGroup
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
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
            Text("Developer")
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
                .accessibilityLabel("Back")
                Spacer()
            }
        }
        .frame(height: 56)
    }

    private var opacityGroup: some View {
        SettingsGroup {
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
        SettingsGroup {
            SliderRow(
                label: "Translation X",
                value: $tuning.translationScaleX,
                range: 0...180,
                format: .decimal
            )
            SettingsDivider()
            SliderRow(
                label: "Translation Y",
                value: $tuning.translationScaleY,
                range: 0...180,
                format: .decimal
            )
            SettingsDivider()
            SliderRow(
                label: "Rotation (degrees)",
                value: $tuning.rotationDegrees,
                range: 0...60,
                format: .decimal
            )
            SettingsDivider()
            SliderRow(
                label: "Card blend depth",
                value: $cardBlendTuning.depthScale,
                range: 0...20,
                format: .decimal
            )
        }
    }

    private var gradientGroup: some View {
        SettingsGroup {
            SliderRow(
                label: "Empty-state edge reach",
                value: $gradientTuning.edgeReach,
                range: 0...1,
                format: .percent
            )
        }
    }

    private var resetGroup: some View {
        SettingsGroup {
            SettingsRow(label: "Reset to defaults", onTap: {
                tuning.reset()
                gradientTuning.reset()
                cardBlendTuning.reset()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 44, height: 43)
                    .accessibilityHidden(true)
            }
        }
    }
}

struct SliderRow: View {

    enum Format { case percent, decimal }

    @Environment(\.colorScheme) private var scheme
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: Format

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(label)
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var valueText: String {
        switch format {
        case .percent:
            return "\(Int((value * 100).rounded()))%"
        case .decimal:
            return String(format: "%.1f", value)
        }
    }
}
