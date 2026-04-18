import Foundation

public struct DeviceAttitude: Hashable, Sendable {
    public let pitch: Double
    public let roll: Double

    public init(pitch: Double, roll: Double) {
        self.pitch = pitch
        self.roll = roll
    }

    public static let zero = DeviceAttitude(pitch: 0, roll: 0)

    public func clamped(to range: ClosedRange<Double> = -1.0...1.0) -> DeviceAttitude {
        DeviceAttitude(
            pitch: min(max(pitch, range.lowerBound), range.upperBound),
            roll: min(max(roll, range.lowerBound), range.upperBound)
        )
    }
}
