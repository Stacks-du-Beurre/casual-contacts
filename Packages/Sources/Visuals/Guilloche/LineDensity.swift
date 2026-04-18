import Foundation

public extension CCVisuals.Guilloche {
    enum LineDensity: Sendable {
        /// 15 paths — used on Card detail variants (Medium, Large).
        case cards
        /// 7 paths — used on Recommended section cards (Phase 3+).
        case recommended
        /// 7 paths — used on small list cards via the `_Preview.svg` variant.
        case preview

        public var expectedPathCount: Int {
            switch self {
            case .cards: return 15
            case .recommended, .preview: return 7
            }
        }
    }
}
