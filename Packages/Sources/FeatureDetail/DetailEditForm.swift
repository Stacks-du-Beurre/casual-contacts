import SwiftUI
import CoreModels
import DesignSystem
import Foundation

/// Editable form for an existing `Record`. Mirrors the field layout of
/// `CreateFormFields` but operates on a mutable local copy of the record
/// and emits the updated value through `onSave` when the user confirms.
public struct DetailEditForm: View {

    public let original: Record
    public let onCancel: () -> Void
    public let onSave: (Record) -> Void

    @State private var name: String
    @State private var description: String
    @State private var zodiacSign: ZodiacSign?
    @State private var showingZodiacPicker = false

    public init(
        record: Record,
        onCancel: @escaping () -> Void,
        onSave: @escaping (Record) -> Void
    ) {
        self.original = record
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: record.name)
        _description = State(initialValue: record.description)
        _zodiacSign = State(initialValue: record.zodiacSign)
    }

    private var isSaveable: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var updatedRecord: Record {
        var next = original
        next.name = name
        next.description = description
        next.zodiacSign = zodiacSign
        next.updatedAt = Date()
        return next
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Name", text: $name)
                    .font(CCDesign.Typography.description)
                    .textFieldStyle(.roundedBorder)

                TextField("Description", text: $description, axis: .vertical)
                    .font(CCDesign.Typography.descriptionSmall)
                    .lineLimit(3, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Zodiac:")
                        .font(CCDesign.Typography.caption1)
                    Button {
                        showingZodiacPicker = true
                    } label: {
                        Text(zodiacSign?.rawValue.capitalized ?? String(localized: "Add", bundle: .module))
                            .font(CCDesign.Typography.caption1)
                    }
                }

                if let label = original.location?.label {
                    Text(String(localized: "Location: \(label)", bundle: .module))
                        .font(CCDesign.Typography.caption2)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Edit")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(updatedRecord)
                    }
                    .disabled(!isSaveable)
                }
            }
            .sheet(isPresented: $showingZodiacPicker) {
                DetailZodiacPickerSheet(selection: $zodiacSign)
            }
        }
    }
}

private struct DetailZodiacPickerSheet: View {
    @Binding var selection: ZodiacSign?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("None") {
                        selection = nil
                        dismiss()
                    }
                }
                Section("Sign") {
                    ForEach(ZodiacSign.allCases, id: \.self) { sign in
                        Button(sign.rawValue.capitalized) {
                            selection = sign
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Zodiac")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
