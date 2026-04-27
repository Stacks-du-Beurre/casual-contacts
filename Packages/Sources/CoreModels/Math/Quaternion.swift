import Foundation

/// Plain-math quaternion used by `RelativeRotationRebaser` to compute rotation
/// deltas without depending on simd or QuaternionKit. Conventions follow
/// CoreMotion's `CMQuaternion`: (x, y, z) is the imaginary/vector part,
/// `w` is the scalar.
public struct Quaternion: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var z: Double
    public var w: Double

    public init(x: Double, y: Double, z: Double, w: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    public static let identity = Quaternion(x: 0, y: 0, z: 0, w: 1)

    public var conjugate: Quaternion { Quaternion(x: -x, y: -y, z: -z, w: w) }

    public var magnitude: Double { (x * x + y * y + z * z + w * w).squareRoot() }

    public var normalized: Quaternion {
        let m = magnitude
        guard m > 0 else { return .identity }
        return Quaternion(x: x / m, y: y / m, z: z / m, w: w / m)
    }

    /// Canonical sign — q and -q represent the same rotation. Forcing
    /// `w >= 0` keeps slerp on the short-arc side.
    public var canonical: Quaternion { w < 0 ? Quaternion(x: -x, y: -y, z: -z, w: -w) : self }

    /// Hamilton product. Reading: applying `lhs` after `rhs`.
    public static func * (lhs: Quaternion, rhs: Quaternion) -> Quaternion {
        Quaternion(
            x: lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
            y: lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
            z: lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w,
            w: lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z
        )
    }

    /// Spherical linear interpolation. `t = 0` returns `q1`, `t = 1` returns `q2`,
    /// constant angular speed in between. Falls back to nlerp when nearly
    /// parallel for numerical stability.
    public static func slerp(from q1: Quaternion, to q2: Quaternion, t: Double) -> Quaternion {
        var a = q1
        var dot = a.x * q2.x + a.y * q2.y + a.z * q2.z + a.w * q2.w
        if dot < 0 {
            a = Quaternion(x: -a.x, y: -a.y, z: -a.z, w: -a.w)
            dot = -dot
        }
        if dot > 0.9995 {
            return Quaternion(
                x: a.x + t * (q2.x - a.x),
                y: a.y + t * (q2.y - a.y),
                z: a.z + t * (q2.z - a.z),
                w: a.w + t * (q2.w - a.w)
            ).normalized
        }
        let theta0 = acos(min(1, max(-1, dot)))
        let theta = theta0 * t
        let sinTheta = sin(theta)
        let sinTheta0 = sin(theta0)
        let s1 = cos(theta) - dot * sinTheta / sinTheta0
        let s2 = sinTheta / sinTheta0
        return Quaternion(
            x: s1 * a.x + s2 * q2.x,
            y: s1 * a.y + s2 * q2.y,
            z: s1 * a.z + s2 * q2.z,
            w: s1 * a.w + s2 * q2.w
        )
    }
}
