import CoreModels
import SwiftUI
import Visuals

/// Stripped-down create scene used to isolate the save button's safe-area /
/// gradient behavior. Only keeps the top-level layout primitives that dock
/// the save button at the bottom and let it sit above the keyboard.
public struct SimpleCreateRecordScene: View {
    public let attitude: DeviceAttitude
    public let timeOfDay: TimeOfDay
    public let onSave: () -> Void

    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    public init(
        attitude: DeviceAttitude,
        timeOfDay: TimeOfDay,
        onSave: @escaping () -> Void
    ) {
        self.attitude = attitude
        self.timeOfDay = timeOfDay
        self.onSave = onSave
    }

    public var body: some View {
        ZStack {
            // Background fills the whole sheet, ignoring safe area + keyboard,
            // so color extends behind the keyboard rather than ending at its top.
            Color.red
                .ignoresSafeArea()

            // Foreground respects safe area and keyboard avoidance, so the
            // TextField and SaveButton dock correctly above the keyboard.
            VStack(spacing: 0) {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .focused($nameFocused)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                Spacer(minLength: 0)

                SaveButton(
                    isEnabled: true,
                    timeOfDay: timeOfDay,
                    attitude: attitude,
                    action: onSave
                )
            }
        }
        .onAppear { nameFocused = true }
    }
}
