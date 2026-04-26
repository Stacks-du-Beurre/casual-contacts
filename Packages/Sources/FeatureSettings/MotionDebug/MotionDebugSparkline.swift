import SwiftUI
import CoreModels

/// Multi-channel line chart over a time window. Each channel is one (label,
/// color, value-extractor) tuple; the canvas draws each as a `Path` over the
/// last `windowDuration` seconds, with a faint zero-line and a y-range
/// caller-supplied so semantically related rows can share scales (e.g. all
/// quaternion components at ±1).
///
/// Drawing is driven by the parent's TimelineView, so the canvas only
/// re-evaluates at display refresh.
struct MotionDebugSparkline: View {

    struct Channel {
        let label: String
        let color: Color
        let value: @Sendable (MotionDebugSample) -> Double
    }

    let samples: [MotionDebugSample]
    let referenceTime: Date
    let windowDuration: TimeInterval
    let yRange: ClosedRange<Double>
    let channels: [Channel]

    var body: some View {
        Canvas { context, size in
            // Background + zero line
            let zeroNormalized = (0 - yRange.lowerBound) / (yRange.upperBound - yRange.lowerBound)
            let zeroY = size.height * (1 - zeroNormalized)
            let zeroLine = Path { p in
                p.move(to: CGPoint(x: 0, y: zeroY))
                p.addLine(to: CGPoint(x: size.width, y: zeroY))
            }
            context.stroke(zeroLine, with: .color(.gray.opacity(0.25)), lineWidth: 0.5)

            guard !samples.isEmpty else { return }

            for channel in channels {
                let path = Path { p in
                    var first = true
                    for sample in samples {
                        let dt = referenceTime.timeIntervalSince(sample.timestamp)
                        guard dt <= windowDuration, dt >= 0 else { continue }
                        let x = size.width * CGFloat(1 - dt / windowDuration)
                        let raw = channel.value(sample)
                        // Non-finite (NaN / ±inf) means "no value here" — the throttled-output
                        // row uses NaN for dropped frames. Break the path so the next finite
                        // sample starts a new sub-path with move(to:), producing a visible gap
                        // rather than a misleading line through the bottom edge.
                        guard raw.isFinite else { first = true; continue }
                        let normalized = (raw - yRange.lowerBound) / (yRange.upperBound - yRange.lowerBound)
                        // Clamp out-of-range values to the edges so pegged signals stay visible
                        // (a ±2 input on a ±1 axis snaps to the top/bottom edge — distinguishable
                        // from a true gap above).
                        let clamped = min(max(normalized, 0), 1)
                        let y = size.height * CGFloat(1 - clamped)
                        let point = CGPoint(x: x, y: y)
                        if first {
                            p.move(to: point)
                            first = false
                        } else {
                            p.addLine(to: point)
                        }
                    }
                }
                context.stroke(path, with: .color(channel.color), lineWidth: 1.0)
            }
        }
    }
}
