import SwiftUI
import DesignSystem

/// FAB per Figma `Add_btn` (`44:11214` light / `106:2486` dark):
/// 56 pt filled circle with a centered `+` glyph. Fill and glyph colors
/// invert per colorScheme — caller passes them explicitly.
struct AddButton: View {
    let action: () -> Void
    let fill: Color
    let glyph: Color

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .frame(width: 56, height: 56)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(glyph)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
