import SwiftUI
import DesignSystem

/// Nav-bar left-item per Figma `Sorting` (`45:4392` / `189:150`):
/// up/down arrow glyph, no circular fill. Destination is the
/// Default + Advanced Sorting screens (deferred to v1.1+) — for now
/// the button is rendered but its tap is a no-op placeholder so the
/// nav bar matches Figma visually.
struct SortingButton: View {
    let action: () -> Void
    let glyph: Color

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(glyph)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
