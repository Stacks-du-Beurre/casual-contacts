import CoreModels
import DesignSystem
import Foundation
import SwiftUI
import Visuals

/// Full-width button reusing the card's time-of-day gradient so it reads
/// as a continuation of the card above. Centered label (defaults to "SAVE").
struct SaveButton: View {
    let label: String
    private let usesDefaultLabel: Bool
    let isEnabled: Bool
    let timeOfDay: TimeOfDay
    let attitude: DeviceAttitude
    let action: () -> Void

    @Bindable private var motionTuning = MotionTuning.shared
    @Environment(\.locale) private var locale

    init(
        label: String? = nil,
        isEnabled: Bool,
        timeOfDay: TimeOfDay,
        attitude: DeviceAttitude,
        action: @escaping () -> Void
    ) {
        self.label = label ?? "SAVE"
        self.usesDefaultLabel = label == nil
        self.isEnabled = isEnabled
        self.timeOfDay = timeOfDay
        self.attitude = attitude
        self.action = action
    }

    var body: some View {
        ZStack {
            GradientLayer(
                timeOfDay: timeOfDay,
                attitude: attitude,
                mode: .balancedAtRest,
                gain: motionTuning.saveButtonGradientGain
            )

            Text(localizedLabel)
                .font(CCDesign.Typography.headline)
                .tracking(CCDesign.Typography.Tracking.headline)
                .foregroundStyle(CCDesign.Colors.L0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .clipped()
        .opacity(isEnabled ? 1 : 0.35)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEnabled { action() }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("saveRecordButton")
    }

    private var localizedLabel: String {
        usesDefaultLabel
            ? ModuleLocalization.string("SAVE", locale: locale)
            : label
    }
}
