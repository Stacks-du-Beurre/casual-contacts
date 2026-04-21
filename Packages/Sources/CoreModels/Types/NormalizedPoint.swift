import Foundation

/// Point in normalized image coordinates (origin top-left), both axes ∈ [0, 1].
/// Used to locate a feature-of-interest (e.g. a detected face) within a photo
/// without tying the value to pixel dimensions.
public struct NormalizedPoint: Hashable, Codable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = Self.clamp(x)
        self.y = Self.clamp(y)
    }

    public static let center = NormalizedPoint(x: 0.5, y: 0.5)

    private static func clamp(_ v: Double) -> Double {
        min(max(v, 0), 1)
    }
}
