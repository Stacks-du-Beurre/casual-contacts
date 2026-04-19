import CoreModels
import DesignSystem
import SwiftUI
import Visuals

/// Full-width SAVE button reusing the card's time-of-day gradient so it reads
/// as a continuation of the card above.
struct SaveButton: View {
    let isEnabled: Bool
    let timeOfDay: TimeOfDay
    let attitude: DeviceAttitude
    let action: () -> Void

    var body: some View {
        ZStack {
            GradientLayer(timeOfDay: timeOfDay, attitude: attitude)
                .rotationEffect(.degrees(180))

            Text("SAVE")
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
}
