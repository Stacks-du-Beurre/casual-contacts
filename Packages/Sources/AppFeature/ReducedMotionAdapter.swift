import Foundation
import CoreModels

/// Pure helper that forces attitude to `.zero` when the user has Reduce Motion enabled.
/// Keeping this pure means it compiles on macOS (UIKit-free) and is unit-testable
/// without simulator toggles.
public enum ReducedMotionAdapter {
    public static func attitude(raw: DeviceAttitude, reduceMotionEnabled: Bool) -> DeviceAttitude {
        reduceMotionEnabled ? .zero : raw
    }
}
