import Foundation

/// Keeps the rotation artwork and the deepest end of the blend stack coplanar.
public enum CardSceneDepth {
    public static let deepestBlendFraction = 0.70
    public static func blendFraction(index: Int, count: Int, reversed: Bool) -> Double {
        guard count > 1 else { return 0 }
        let t = Double(min(max(index, 0), count - 1)) / Double(count - 1)
        return reversed ? deepestBlendFraction * (1 - t) : deepestBlendFraction * t
    }
}

/// Affine projection of a plane parallel to and behind the phone screen.
/// Coordinates and depths use meters. The reference pose preserves the artwork
/// at calibration; the current pose changes both scale and translation.
public struct WindowPlaneProjection: Sendable {
    public let scale: Double
    public let translationX: Double
    public let translationY: Double

    public init?(eye: ViewerPosition, reference: ViewerPosition, depth: Double) {
        guard eye.isValid, reference.isValid, depth.isFinite, depth >= 0 else { return nil }
        let currentScale = eye.distance / (eye.distance + depth)
        let referenceScale = reference.distance / (reference.distance + depth)
        scale = currentScale / referenceScale
        translationX = depth * eye.x / (eye.distance + depth)
            - scale * depth * reference.x / (reference.distance + depth)
        translationY = depth * eye.y / (eye.distance + depth)
            - scale * depth * reference.y / (reference.distance + depth)
    }
}
