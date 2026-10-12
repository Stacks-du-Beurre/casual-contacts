import Foundation

/// Eye midpoint in portrait camera-view coordinates (meters, x right, y up).
public struct ViewerPosition: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var distance: Double

    public init(x: Double, y: Double, distance: Double) {
        self.x = x
        self.y = y
        self.distance = distance
    }

    /// Neutral viewpoint above the physical screen center, expressed from
    /// the front camera. It is independent of the first detected face.
    public static func screenCentered(cameraHeightMeters: Double, distance: Double = 0.4) -> Self {
        Self(x: 0, y: -cameraHeightMeters, distance: distance)
    }

    public var isValid: Bool {
        x.isFinite && y.isFinite && distance.isFinite && (0.05...1.2).contains(distance)
    }
}

/// Converts the viewing ray to the existing card's bounded depth-layer input.
/// Calibration stays fixed until explicitly reset: holding a new position must
/// not silently erase camera-driven perspective as the gyro rebaser does.
public struct ViewerParallax: Sendable {
    private var origin: ViewerPosition?
    private let fixedReference: ViewerPosition?

    public init(reference: ViewerPosition? = nil) {
        fixedReference = reference
        origin = reference
    }

    public mutating func reset() { origin = fixedReference }

    public mutating func attitude(for position: ViewerPosition) -> DeviceAttitude? {
        guard position.isValid else { return nil }
        if origin == nil { origin = position }
        guard let origin else { return nil }
        let fullScale = tan(15.0 * .pi / 180.0)
        let x = fixedReference == nil
            ? position.x / position.distance - origin.x / origin.distance
            : (position.x - origin.x) / position.distance
        let y = fixedReference == nil
            ? position.y / position.distance - origin.y / origin.distance
            : (position.y - origin.y) / position.distance
        return DeviceAttitude(
            pitch: -y / fullScale,
            roll: x / fullScale
        ).clamped()
    }
}

/// Frame-rate-independent damping, updated by the display clock rather than
/// the camera. A 15 Hz input still produces intermediate display frames.
public struct DisplayAttitudeSmoother: Sendable {
    public private(set) var value: DeviceAttitude = .zero
    public init() {}

    public mutating func reset(to value: DeviceAttitude = .zero) { self.value = value }

    public mutating func step(toward target: DeviceAttitude, elapsed: Double) -> DeviceAttitude {
        guard elapsed.isFinite, elapsed > 0 else { return value }
        let alpha = 1 - exp(-min(elapsed, 0.1) / 0.075)
        value = DeviceAttitude(
            pitch: value.pitch + alpha * (target.pitch - value.pitch),
            roll: value.roll + alpha * (target.roll - value.roll)
        )
        return value
    }
}
