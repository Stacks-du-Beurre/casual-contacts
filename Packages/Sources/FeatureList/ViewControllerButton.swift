import SwiftUI
import DesignSystem

/// Nav-bar right-item per Figma `View_Controller` (`274:10636` / `215:8`):
/// 24 pt filled circle with a centered horizontal ellipsis glyph.
/// Fill + glyph colors invert per dark/light mode — caller passes them explicitly.
struct ViewControllerButton: View {
    let action: () -> Void
    let fill: Color
    let glyph: Color

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .frame(width: 24, height: 24)
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(glyph)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
