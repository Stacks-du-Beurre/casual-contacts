import SwiftUI
import CoreModels
import DesignSystem
import Visuals

public struct CreateRecordScene: View {

    public let attitude: DeviceAttitude
    public let paths: any CardPathProvider
    public let onCancel: () -> Void
    public let onSave: (RecordDraft) -> Void

    @State private var model = CreateRecordModel()
    @State private var showingZodiacPicker = false

    public init(
        attitude: DeviceAttitude,
        paths: any CardPathProvider,
        onCancel: @escaping () -> Void,
        onSave: @escaping (RecordDraft) -> Void
    ) {
        self.attitude = attitude
        self.paths = paths
        self.onCancel = onCancel
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CardView(record: model.previewRecord, size: .medium, attitude: attitude, paths: paths)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()

                CreateFormFields(model: model, isZodiacPickerShowing: $showingZodiacPicker)

                Spacer()
            }
            .navigationTitle("Person")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(model.draft)
                    }
                    .disabled(!model.isSaveable)
                    .accessibilityIdentifier("saveRecordButton")
                }
            }
            .sheet(isPresented: $showingZodiacPicker) {
                ZodiacPickerSheet(selection: $model.zodiacSign)
            }
        }
    }
}
