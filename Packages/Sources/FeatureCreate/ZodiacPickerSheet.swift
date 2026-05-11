import SwiftUI
import CoreModels
import DesignSystem

struct ZodiacPickerSheet: View {
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
                        Button(ModuleLocalization.zodiacDisplayName(sign, locale: locale)) {
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
