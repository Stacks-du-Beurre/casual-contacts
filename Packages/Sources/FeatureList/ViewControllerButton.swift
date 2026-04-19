import SwiftUI
import DesignSystem

/// Nav-bar right-item per Figma `View_Controller` (`274:10636` / `215:8`):
/// 24 pt filled circle with a centered horizontal ellipsis glyph.
/// Fill + glyph colors invert per dark/light mode — caller passes them explicitly.
struct ViewControllerButton: View {
    let action: () -> Void
    let fill: Color
    let glyph: Color
    /// Caller-supplied canvas scale (≥1). Floors at the Figma 24/11/44pt sizes
    /// and grows proportionally on wider screens. See `RecordsListScene`.
    var scale: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .frame(width: 24 * scale, height: 24 * scale)
                Image(systemName: "ellipsis")
                    .font(.system(size: 11 * scale, weight: .bold))
                    .foregroundStyle(glyph)
            }
            .frame(width: 44 * scale, height: 44 * scale)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
