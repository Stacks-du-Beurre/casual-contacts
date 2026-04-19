import SwiftUI
import CoreModels
import DesignSystem
import Visuals

/// Full-width SAVE button reusing the card's time-of-day gradient so it reads
/// as a continuation of the card above.
struct SaveButton: View {
    let isEnabled: Bool
    let timeOfDay: TimeOfDay
    let attitude: DeviceAttitude
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                GradientLayer(timeOfDay: timeOfDay, attitude: attitude)

                Text("SAVE")
                    .font(CCDesign.Typography.headline)
                    .tracking(CCDesign.Typography.Tracking.headline)
                    .foregroundStyle(CCDesign.Colors.L0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("saveRecordButton")
    }
}
