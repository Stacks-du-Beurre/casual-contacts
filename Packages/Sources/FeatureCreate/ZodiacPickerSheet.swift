import SwiftUI
import CoreModels
import DesignSystem

struct ZodiacPickerSheet: View {
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
