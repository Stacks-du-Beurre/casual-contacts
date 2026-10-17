#if os(iOS)
import QuartzCore

/// Requests are hints: iOS can reduce cadence for system reasons.
public enum CardDisplayFrameRate {
    public static func range(lowPowerMode: Bool, maximumRefreshHz: Float) -> CAFrameRateRange {
        let maximum = min(lowPowerMode ? 60 : 120, max(30, maximumRefreshHz))
        return CAFrameRateRange(minimum: min(lowPowerMode ? 30 : 60, maximum),
                                maximum: maximum, preferred: maximum)
    }
}
#endif
