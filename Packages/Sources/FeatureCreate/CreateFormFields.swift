import SwiftUI
import CoreModels
import DesignSystem

struct CreateFormFields: View {

    @Bindable var model: CreateRecordModel

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

            if let label = model.location?.label {
                Text("Location: \(label)")
                    .font(CCDesign.Typography.caption2)
            }
        }
        .padding()
    }
}
