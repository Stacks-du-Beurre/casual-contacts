import Foundation

/// Opens the depth scene once, without slowing steady tracking or collapsing
/// the scene when the camera temporarily loses the face.
public struct SceneAcquisitionEasing: Sendable {
    public private(set) var value = 0.0
    private var progress = 0.0
    public init() {}

    @discardableResult
    public mutating func step(hasPose: Bool, elapsed: Double) -> Double {
        guard hasPose, elapsed.isFinite, elapsed > 0 else { return value }
        progress = min(1, progress + min(elapsed, 0.1) / 0.4)
        value = progress * progress * (3 - 2 * progress)
        return value
    }
}
