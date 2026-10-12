import Foundation

/// Rotates the last observed eye around the camera when the phone turns.
/// Assumes the viewer and camera position stay fixed in world space.
public struct InertialViewer: Sendable {
    private var eye: ViewerPosition?
    private var orientation: Quaternion?

    public init() {}

    public mutating func calibrate(eye: ViewerPosition, orientation: Quaternion) {
        guard eye.isValid, Self.valid(orientation) else { return }
        self.eye = eye
        self.orientation = orientation.normalized
    }

    public func estimate(orientation current: Quaternion) -> ViewerPosition? {
        guard let eye, let orientation, Self.valid(current) else { return nil }
        let rotation = current.normalized.conjugate * orientation
        let vector = Quaternion(x: eye.x, y: eye.y, z: eye.distance, w: 0)
        let rotated = rotation * vector * rotation.conjugate
        let result = ViewerPosition(x: rotated.x, y: rotated.y, distance: rotated.z)
        return result.isValid ? result : nil
    }

    private static func valid(_ q: Quaternion) -> Bool {
        q.x.isFinite && q.y.isFinite && q.z.isFinite && q.w.isFinite && q.magnitude > 0.000001
    }
}
