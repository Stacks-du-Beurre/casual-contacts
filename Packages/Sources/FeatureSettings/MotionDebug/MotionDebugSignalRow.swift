import SwiftUI
import CoreModels

/// One row in the debug screen's scrolling list. Left side: row title +
/// fixed-width numeric column showing each channel's current value. Right
/// side: the rolling-strip sparkline.
struct MotionDebugSignalRow: View {

    let title: String
    let latest: MotionDebugSample?
    let samples: [MotionDebugSample]
    let referenceTime: Date
    let windowDuration: TimeInterval
    let yRange: ClosedRange<Double>
    let channels: [MotionDebugSparkline.Channel]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(channels.enumerated()), id: \.offset) { _, channel in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(channel.color)
                            .frame(width: 6, height: 6)
                        Text(channel.label)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Text(numericString(for: channel))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
            }
            .frame(width: 130, alignment: .leading)

            MotionDebugSparkline(
                samples: samples,
                referenceTime: referenceTime,
                windowDuration: windowDuration,
                yRange: yRange,
                channels: channels
            )
            .frame(maxWidth: .infinity)
            .frame(height: 60)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }

    private func numericString(for channel: MotionDebugSparkline.Channel) -> String {
        guard let latest else { return "—" }
        let value = channel.value(latest)
        return String(format: "%+0.3f", value)
    }
}
