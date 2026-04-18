import SwiftUI
import CoreModels
import DesignSystem

struct CreateFormFields: View {

    @Bindable var model: CreateRecordModel
    @Binding var isZodiacPickerShowing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Name", text: $model.name)
                .font(CCDesign.Typography.description)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("nameField")

            TextField("Description", text: $model.description, axis: .vertical)
                .font(CCDesign.Typography.descriptionSmall)
                .lineLimit(3, reservesSpace: true)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Zodiac:")
                    .font(CCDesign.Typography.caption1)
                Button {
                    isZodiacPickerShowing = true
                } label: {
                    Text(model.zodiacSign?.rawValue.capitalized ?? "Add")
                        .font(CCDesign.Typography.caption1)
                }
            }

            if let label = model.location?.label {
                Text("Location: \(label)")
                    .font(CCDesign.Typography.caption2)
            }
        }
        .padding()
    }
}
