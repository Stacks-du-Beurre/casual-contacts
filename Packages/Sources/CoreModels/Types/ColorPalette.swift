import Foundation

/// Placeholder identity for a time-of-day palette.
/// The actual gradient definitions are supplied by the `DesignSystem` module in Plan 2.
public struct ColorPalette: Hashable, Sendable {
    public let timeOfDay: TimeOfDay

    public init(timeOfDay: TimeOfDay) {
        self.timeOfDay = timeOfDay
    }
}
