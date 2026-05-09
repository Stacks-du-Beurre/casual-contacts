import SwiftUI
import CoreModels

/// Which signal source drives the 2D dot. Each maps a `MotionDebugSample` to
/// a unit-square position, so a developer can tap-compare them and decide
/// which one drives the smoothest animation across the full orientation
/// sphere — including past-vertical / upside-down where Euler-derived
/// signals discontinuously flip.
enum MotionDebugDotSource: String, CaseIterable, Hashable {
    /// Quaternion-delta from a captured baseline pose. Decomposes into
    /// signed rotation around the device X-axis (pitch) and Y-axis (twist).
    /// No Euler singularity, linear angular response, baseline-pose
    /// independent. Default — this is the one designed to actually work.
    case relative
    /// `shaped.{roll, pitch}` — current production pipeline output.
    /// Goes erratic near pitch = ±π/2 (CoreMotion Euler singularity).
    case rawEuler
    /// Gravity direction in device frame, derived from `rawQuaternion`
    /// via `g = q⁻¹ · (0,0,-1) · q`. Continuous everywhere; differs from
    /// `.gravity` in dynamic motion (no live-accelerometer fusion noise).
    case quaternion
    /// `motion.gravity.{x, y}` — Apple's sensor-fused gravity direction.
    /// Continuous everywhere, slightly noisier than `.quaternion` under
    /// real-world acceleration because it folds in accelerometer data.
    case gravity

    var label: String {
        switch self {
        case .relative:   return "Relative"
        case .rawEuler:   return "Euler"
        case .quaternion: return "Quat"
        case .gravity:    return "Gravity"
        }
    }
}

/// Pinned top region of the debug screen.
///
/// Left: a unit-square 2D plot driven by one of three signal sources
/// (selectable via the row of tabs beneath the dot). Origin at center,
/// ±1 at edges. A faint trail of the last `trailDuration` seconds gives
/// motion direction at a glance.
///
/// Right: three state chips — settle countdown, rebase progress, and
/// the throttled emission rate (Hz) over the last 1 s.
struct MotionDebugPinnedRegion: View {

    @Bindable private var motionTuning = MotionTuning.shared

    let snapshot: MotionDebugViewModel.Snapshot
    let emissionRate: Int
    let referenceTime: Date
    let dotSource: MotionDebugDotSource
    let gravityRebaser: GravityRebaser
    let relativeRebaser: RelativeRotationRebaser
    /// Angle (in radians) from baseline that maps to the box edge in the
    /// `.relative` mode. Tunable via the slider above the dot.
    let relativeFullScaleRadians: Double

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
                    let pos = position(for: sample, in: size, isLatest: false)
                    if first { p.move(to: pos); first = false }
                    else { p.addLine(to: pos) }
                }
            }
            context.stroke(trail, with: .color(.accentColor.opacity(0.5)), lineWidth: 1)

            // Current dot
            if let latest = snapshot.latest {
                let pos = position(for: latest, in: size, isLatest: true)
                let dot = Path(ellipseIn: CGRect(x: pos.x - 4, y: pos.y - 4, width: 8, height: 8))
                context.fill(dot, with: .color(.accentColor))
            }
        }
    }

    /// Map a sample to a (x, y) point on the unit-square canvas. Each source
    /// produces a value in roughly ±1, then we shift to [0, 1] and scale to
    /// canvas size. Out-of-range values clip to the edges (the `min`/`max`
    /// guards handle non-unit-magnitude gravity / quaternion-derived vectors).
    private func position(for sample: MotionDebugSample, in size: CGSize, isLatest: Bool) -> CGPoint {
        let (rawX, rawY): (Double, Double)
        switch dotSource {
        case .relative:
            // Divide by the user-tunable full-scale: smaller value = more
            // sensitive (less rotation drives the dot to the edge).
            let scale = max(relativeFullScaleRadians, .pi / 180)  // floor at 1°
            if isLatest {
                rawX = relativeRebaser.relativeTwist / scale
                rawY = relativeRebaser.relativePitch / scale
            } else {
                let (pitch, twist) = relativeRebaser.angles(forQuaternion: sample.rawQuaternion)
                rawX = twist / scale
                rawY = pitch / scale
            }
        case .rawEuler:
            rawX = sample.shaped.roll
            rawY = sample.shaped.pitch
        case .quaternion:
            // Standard formula for the gravity direction in device frame
            // given a unit quaternion q = (x, y, z, w) representing the
            // device's orientation in world frame. Continuous through
            // every orientation, including past vertical.
            let q = sample.rawQuaternion
            let gx = 2 * (q.x * q.z - q.w * q.y)
            let gy = 2 * (q.w * q.x + q.y * q.z)
            rawX = gx
            rawY = gy
        case .gravity:
            if isLatest {
                // Live dot uses the rebaser's unwrapped, baseline-subtracted
                // angles so a continuous physical rotation past upside-down
                // pins the dot at the box edge instead of teleporting.
                // ÷ π means 90° tilt sits halfway between center and edge.
                rawX = gravityRebaser.relativeRoll / .pi
                rawY = gravityRebaser.relativePitch / .pi
            } else {
                // Trail samples don't have unwrapped state stored per-sample;
                // recompute principal-value relative angles. Approximate but
                // visually fine for the 1 s history — the live dot is the
                // continuous one.
                let g = sample.gravity
                let pitch = atan2(g.y, -g.z) - gravityRebaser.baselinePitch
                let roll = atan2(g.x, -g.z) - gravityRebaser.baselineRoll
                rawX = roll / .pi
                rawY = pitch / .pi
            }
        }
        let nx = min(max((rawX + 1) / 2, 0), 1)
        let ny = min(max((rawY + 1) / 2, 0), 1)
        return CGPoint(x: size.width * CGFloat(nx), y: size.height * CGFloat(ny))
    }

    private var settleChip: some View {
        let total = motionTuning.zeroPointSettleDuration
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
