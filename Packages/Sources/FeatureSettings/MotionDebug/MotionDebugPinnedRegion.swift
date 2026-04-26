import SwiftUI
import CoreModels

/// Pinned top region of the debug screen.
///
/// Left half: a unit-square 2D plot of (shaped.pitch, shaped.roll). Origin
/// at center, ±1 at edges. A faint trail of the last `trailDuration` seconds
/// gives motion direction at a glance.
///
/// Right half: three state chips — settle countdown, rebase progress, and
/// the throttled emission rate (Hz) over the last 1 s.
struct MotionDebugPinnedRegion: View {

    let snapshot: MotionDebugViewModel.Snapshot
    let emissionRate: Int
    let referenceTime: Date

    private let trailDuration: TimeInterval = 1.0

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            dot
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 180)

            VStack(alignment: .leading, spacing: 12) {
                settleChip
                rebaseChip
                hzChip
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
    }

    private var dot: some View {
        Canvas { context, size in
            // Frame
            let frame = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 4)
            context.stroke(frame, with: .color(.gray.opacity(0.4)), lineWidth: 1)

            // Crosshairs
            let cross = Path { p in
                p.move(to: CGPoint(x: size.width / 2, y: 0))
                p.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                p.move(to: CGPoint(x: 0, y: size.height / 2))
                p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            }
            context.stroke(cross, with: .color(.gray.opacity(0.25)), lineWidth: 0.5)

            // Trail (last `trailDuration`)
            let trail = Path { p in
                var first = true
                for sample in snapshot.samples {
                    let dt = referenceTime.timeIntervalSince(sample.timestamp)
                    guard dt <= trailDuration, dt >= 0 else { continue }
                    let x = size.width * CGFloat((sample.shaped.pitch + 1) / 2)
                    let y = size.height * CGFloat((sample.shaped.roll + 1) / 2)
                    let point = CGPoint(x: x, y: y)
                    if first { p.move(to: point); first = false }
                    else { p.addLine(to: point) }
                }
            }
            context.stroke(trail, with: .color(.accentColor.opacity(0.5)), lineWidth: 1)

            // Current dot
            if let latest = snapshot.latest {
                let cx = size.width * CGFloat((latest.shaped.pitch + 1) / 2)
                let cy = size.height * CGFloat((latest.shaped.roll + 1) / 2)
                let dot = Path(ellipseIn: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8))
                context.fill(dot, with: .color(.accentColor))
            }
        }
    }

    private var settleChip: some View {
        let total: TimeInterval = 3.5
        let remaining = max(0, total - (snapshot.latest?.secondsSinceSettleReset ?? 0))
        let armed = remaining > 0 && remaining < total
        return chip(
            label: "settle",
            value: String(format: "%.1fs", remaining),
            tint: armed ? .orange : .secondary
        )
    }

    private var rebaseChip: some View {
        let inProgress = snapshot.latest?.isRebaseInProgress == true
        let progress = snapshot.latest?.rebaseProgress ?? 0
        return HStack(spacing: 8) {
            chip(label: "rebase", value: inProgress ? "in progress" : "idle", tint: inProgress ? .orange : .secondary)
            if inProgress {
                ProgressView(value: progress)
                    .frame(width: 80)
            }
        }
    }

    private var hzChip: some View {
        chip(label: "Hz", value: "\(emissionRate)", tint: .primary)
    }

    private func chip(label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(tint)
        }
    }
}
