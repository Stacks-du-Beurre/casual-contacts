import SwiftUI
import CoreText
import DesignSystem

/// Renders a card description as stacked single-line pills, reproducing the Figma
/// `Cards/Full` (node `6:16`) behavior where each visual line of the description
/// sits in its own 1pt-stroke rounded-rectangle pill.
///
/// Behavior per designer spec:
/// - 1 visual line → 1 pill, sized to content.
/// - 2 visual lines → 2 pills, each sized to its line's content.
/// - 3+ visual lines → 2 pills; the 2nd shows the overflow fragment and tail-
///   truncates with an ellipsis to signal "more".
///
/// Line splitting uses CoreText against the actual render font so the break
/// points match what SwiftUI would draw.
struct DescriptionPills: View {

    let text: String
    let maxPillWidth: CGFloat

    var body: some View {
        let segments = segments()
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                pill(segment)
            }
        }
    }

    private struct Segment {
        let text: String
        /// When true, render the pill stretched to `maxPillWidth` and let SwiftUI
        /// tail-truncate with an ellipsis. When false, the pill hugs its content.
        let truncateToWidth: Bool
    }

    private func segments() -> [Segment] {
        guard !text.isEmpty else { return [] }
        let innerWidth = max(0, maxPillWidth - 12)  // 6pt horizontal padding each side
        let lines = Self.layoutLines(text: text, width: innerWidth)

        switch lines.count {
        case 0:
            return []
        case 1:
            return [Segment(text: lines[0].text, truncateToWidth: false)]
        case 2:
            return [
                Segment(text: lines[0].text, truncateToWidth: false),
                Segment(text: lines[1].text, truncateToWidth: false),
            ]
        default:
            let first = lines[0]
            let ns = text as NSString
            let remainderStart = first.range.location + first.range.length
            let remainder = ns
                .substring(from: remainderStart)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return [
                Segment(text: first.text, truncateToWidth: false),
                Segment(text: remainder, truncateToWidth: true),
            ]
        }
    }

    @ViewBuilder
    private func pill(_ segment: Segment) -> some View {
        let base = Text(segment.text)
            .font(CCDesign.Typography.description)
            .tracking(CCDesign.Typography.Tracking.description)
            .foregroundStyle(.white)
            .lineLimit(1)

        if segment.truncateToWidth {
            base
                .truncationMode(.tail)
                .frame(maxWidth: maxPillWidth - 12, alignment: .leading)
                .frame(height: CCDesign.Typography.LineHeight.description)
                .padding(.horizontal, 6)
                .overlay(Rectangle().stroke(CCDesign.Colors.L2, lineWidth: 1))
        } else {
            base
                .fixedSize(horizontal: true, vertical: false)
                .frame(height: CCDesign.Typography.LineHeight.description)
                .padding(.horizontal, 6)
                .overlay(Rectangle().stroke(CCDesign.Colors.L2, lineWidth: 1))
        }
    }

    // MARK: - Line layout

    struct LineFragment {
        let text: String
        let range: NSRange
    }

    /// Computes the visual lines the description would wrap to, using CoreText
    /// against the same Cormorant Infant SemiBold 18 font SwiftUI renders.
    static func layoutLines(text: String, width: CGFloat) -> [LineFragment] {
        guard !text.isEmpty, width > 0 else { return [] }
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        let font = CTFontCreateWithName("CormorantInfant-SemiBold" as CFString, 18, nil)
        let attributed = NSMutableAttributedString(string: text)
        attributed.addAttribute(.font, value: font, range: fullRange)
        attributed.addAttribute(.kern, value: -0.05, range: fullRange)

        let setter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(
            rect: CGRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude),
            transform: nil
        )
        let frame = CTFramesetterCreateFrame(setter, CFRangeMake(0, 0), path, nil)
        guard let ctLines = CTFrameGetLines(frame) as? [CTLine] else { return [] }

        return ctLines.compactMap { line in
            let cfRange = CTLineGetStringRange(line)
            let range = NSRange(location: cfRange.location, length: cfRange.length)
            guard range.location + range.length <= ns.length else { return nil }
            let substring = ns
                .substring(with: range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !substring.isEmpty else { return nil }
            return LineFragment(text: substring, range: range)
        }
    }
}
