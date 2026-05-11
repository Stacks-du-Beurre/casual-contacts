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
    @Environment(\.locale) private var locale

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
                TextField(ModuleLocalization.string("Name", locale: locale), text: $name)
                    .font(CCDesign.Typography.description)
                    .textFieldStyle(.roundedBorder)

                TextField(ModuleLocalization.string("Description", locale: locale), text: $description, axis: .vertical)
                    .font(CCDesign.Typography.descriptionSmall)
                    .lineLimit(3, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    ModuleLocalization.text("Zodiac:", locale: locale)
                        .font(CCDesign.Typography.caption1)
                    Button {
                        showingZodiacPicker = true
                    } label: {
                        Text(zodiacSign?.rawValue.capitalized ?? ModuleLocalization.string("Add", locale: locale))
                            .font(CCDesign.Typography.caption1)
                    }
                }

                if let label = original.location?.label {
                    Text(Self.locationLabel(label, locale: locale))
                        .font(CCDesign.Typography.caption2)
                }

                Spacer()
            }
            .padding()
            .navigationTitle(ModuleLocalization.string("Edit", locale: locale))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ModuleLocalization.string("Cancel", locale: locale), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(ModuleLocalization.string("Save", locale: locale)) {
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

    static func locationLabel(_ label: String, locale: Locale) -> String {
        ModuleLocalization.string("Location: %@", locale: locale, label)
    }
}

private struct DetailZodiacPickerSheet: View {
    @Binding var selection: ZodiacSign?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(ModuleLocalization.string("None", locale: locale)) {
                        selection = nil
                        dismiss()
                    }
                }
                Section(ModuleLocalization.string("Sign", locale: locale)) {
                    ForEach(ZodiacSign.allCases, id: \.self) { sign in
                        Button(sign.rawValue.capitalized) {
                            selection = sign
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(ModuleLocalization.string("Zodiac", locale: locale))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ModuleLocalization.string("Cancel", locale: locale)) { dismiss() }
                }
            }
        }
    }
}
