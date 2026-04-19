import SwiftUI

public extension CCDesign {
    enum Typography {

        // Sizes respect Dynamic Type when used with `.font(...)` modifier. Values are base sizes.
        public static let title = Font.custom("CormorantSC-SemiBold", size: 33, relativeTo: .largeTitle)
        public static let headline = Font.custom("CormorantSC-Bold", size: 17, relativeTo: .headline)
        // SwiftUI's `.fontWeight(.semibold)` doesn't drive variable-axis weights on
        // `Font.custom("CormorantInfant", ...)` — resolve SemiBold via the named
        // PostScript instance instead so the token actually ships its design weight.
        public static let description = Font.custom("CormorantInfant-SemiBold", size: 18, relativeTo: .body)
        public static let descriptionSmall = Font.custom("CormorantInfant-SemiBold", size: 13, relativeTo: .footnote)
        public static let caption1 = Font.custom("CormorantSC-Bold", size: 12, relativeTo: .caption)
        public static let caption2 = Font.custom("IBMPlexMono-Regular", size: 11, relativeTo: .caption2)

        /// Letter-spacing (tracking) per design spec. Apply via `.tracking(...)` on Text.
        public enum Tracking {
            public static let title: CGFloat = 0
            public static let headline: CGFloat = 2.4
            public static let description: CGFloat = -0.05
            public static let descriptionSmall: CGFloat = -0.2
            public static let caption1: CGFloat = 0.2
            public static let caption2: CGFloat = 0
        }

        /// Line heights per design spec. Apply via `.lineSpacing(...)` where relevant.
        public enum LineHeight {
            public static let title: CGFloat = 33
            public static let headline: CGFloat = 20
            public static let description: CGFloat = 27
            public static let descriptionSmall: CGFloat = 17
            public static let caption1: CGFloat = 12
            public static let caption2: CGFloat = 12
        }
    }
}
