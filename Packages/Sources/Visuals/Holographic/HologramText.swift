import SwiftUI

/// Text with the two-fill treatment from Figma: a 20%-opacity black base fill
/// (NORMAL blend) stacked beneath a 100%-opacity black OVERLAY fill. The net
/// result is a softer-than-pure-black letterform that subtly reveals the
/// backdrop through it — used for the empty-state title and any static
/// "name" label that sits on top of a `HologramPill`.
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
                .foregroundStyle(Color.black.opacity(0.2))

            Text(text)
                .font(font)
                .foregroundStyle(.black)
                .blendMode(.overlay)
        }
    }
}
