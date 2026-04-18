import SwiftUI

/// Text with the two-fill treatment from Figma: a 100%-opacity black OVERLAY
/// base fill stacked beneath a 20%-opacity black NORMAL fill. Order matches
/// Figma's `fills` array (index 0 = bottom), so the OVERLAY blends with the
/// pill contents below the text, and the 20% black paints flat over the
/// result — used for the empty-state title and any static "name" label that
/// sits on top of a `HologramPill`.
///
/// This is NOT the animated title-name hologram from the design-spec PDF
/// section 5 (lighten + luminosity + gyroscope-driven transfusion); that
/// treatment belongs to populated card names and is implemented in
/// `HolographicText`.
public struct HologramText: View {

    public let text: String
    public let font: Font

    public init(_ text: String, font: Font) {
        self.text = text
        self.font = font
    }

    public var body: some View {
        ZStack {
            Text(text)
                .font(font)
                .foregroundStyle(.black)
                .blendMode(.overlay)

            Text(text)
                .font(font)
                .foregroundStyle(Color.black.opacity(0.2))
        }
    }
}
