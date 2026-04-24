import SwiftUI
import CoreModels
import DesignSystem

public struct GuillocheRotationLayer: View, Animatable {

    /// Which calling context the layer is used in — picks the matching
    /// tuning value so the card and empty-state hero can be dialed
    /// independently from the developer-settings panel.
    public enum Usage: Sendable {
        case card
        case emptyState
    }

    public let paths: [Path]
    public let opacity: Double
    public let tint: Color
    public let attitude: DeviceAttitude
    public let usage: Usage
    public var reveal: Double

    /// `Animatable` hook — SwiftUI interpolates `reveal` between frames via
    /// this property and re-invokes `body` each frame, so the Canvas redraws
    /// with staged opacities instead of jumping to the target in one shot.
    nonisolated public var animatableData: Double {
        get { reveal }
        set { reveal = newValue }
    }

    @Bindable private var tuning = GuillocheRotationTuning.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        paths: [Path],
        opacity: Double = 0.2,
        tint: Color = CCDesign.Colors.L4,
        attitude: DeviceAttitude = .zero,
        usage: Usage = .card,
        reveal: Double = 1.0
    ) {
        self.paths = paths
        self.opacity = opacity
        self.tint = tint
        self.attitude = attitude
        self.usage = usage
        self.reveal = reveal
    }

    /// Per-gradient stroke opacity for the **card** rotation guilloche. The
    /// midday gradient is significantly brighter than the others, so the
    /// filigree at the default 0.2 reads as washed out against it; bump to
    /// 0.5 for readable contrast. All other times of day stay at the
    /// baseline 0.2. The empty-state hero may need a different table; keep
    /// this helper card-scoped and add a sibling later if so.
    public static func cardOpacity(for timeOfDay: TimeOfDay) -> Double {
        switch timeOfDay {
        case .midday: return 0.5
        case .dawn, .sunrise, .sunset, .dusk, .night, .midnight: return 0.2
        }
    }

    public var body: some View {
        // `Color.clear` is flex-flex, so this layer reports the parent ZStack's
        // proposed size upward — no size leak from the fixed 380 child. The
        // Canvas overlay is pinned to the 380×380 SVG viewBox so paths always
        // have room to draw at their native coordinates; on the empty-state
        // hero (also 380×380) it aligns 1:1, on the smaller card the swirl
        // overflows symmetrically and the card's outer `.clipped()` crops it —
        // so rotation never clips through the fan itself.
        Color.clear
            .overlay {
                // Rasterize the 72-path stroke pass into a single Metal-backed
                // texture once the stagger has finished. While revealing, skip
                // `drawingGroup` so per-path opacity can animate smoothly.
                Group {
                    if reveal >= 1.0 {
                        canvasContent
                            .frame(width: 380, height: 380)
                            .drawingGroup(opaque: false)
                    } else {
                        canvasContent
                            .frame(width: 380, height: 380)
                    }
                }
                .rotationEffect(.degrees(motionRotation))
                // Second-stage smoothing: the motion service already low-passes
                // the raw CoreMotion stream (`AttitudeLowPass` α=0.1), but the
                // filigree's full-rotation scale amplifies residual jitter.
                // Animating the rotation value lets SwiftUI interpolate
                // between successive samples so the spin reads as a gentle
                // roll rather than a step-every-frame.
                .animation(.easeOut(duration: 0.4), value: motionRotation)
            }
            .accessibilityHidden(true)
    }

    /// Re-strokes every frame while `reveal < 1` so the per-path opacity
    /// ramp is honored. Once fully revealed, a sibling `.drawingGroup` wraps
    /// this view into a cached texture so the rotation animation is cheap.
    private var canvasContent: some View {
        Canvas { context, _ in
            guard reveal > 0 else { return }
            // Under Reduce Motion, skip the stagger and treat `reveal` as a
            // flat opacity multiplier so the filigree cross-fades instead of
            // scribbling in.
            if reduceMotion {
                for path in paths {
                    context.stroke(
                        path,
                        with: .color(tint.opacity(opacity * reveal)),
                        lineWidth: 0.5
                    )
                }
                return
            }

            // Strict sequential reveal: each rotated copy owns a 1/total
            // slice of the reveal window and only starts once the previous
            // copy has finished — no overlap.
            let total = max(paths.count, 1)
            let slot = 1.0 / Double(total)
            for (index, path) in paths.enumerated() {
                let start = Double(index) * slot
                let local = (reveal - start) / slot
                let localReveal = min(max(local, 0), 1)
                guard localReveal > 0 else { continue }
                context.stroke(
                    path,
                    with: .color(tint.opacity(opacity * localReveal)),
                    lineWidth: 0.5
                )
            }
        }
    }

    /// `(roll - pitch) * rotationDegrees`, zeroed under Reduce Motion.
    /// `rotationDegrees` is chosen per-usage so card and empty-state hero
    /// are tuned independently.
    ///   - roll = +1 (phone tilted right)  → +degrees (clockwise)
    ///   - roll = -1 (phone tilted left)   → -degrees (counter-clockwise)
    ///   - pitch = +1 (top away from user) → -degrees (counter-clockwise)
    ///   - pitch = -1 (top toward user)    → +degrees (clockwise)
    private var motionRotation: Double {
        guard !reduceMotion else { return 0 }
        let degrees: Double = switch usage {
        case .card: tuning.cardRotationDegrees
        case .emptyState: tuning.emptyStateRotationDegrees
        }
        return (attitude.roll - attitude.pitch) * degrees
    }

    /// Produces the full 72-step (5° per step) rotation filigree of a single
    /// letter outline — the construction the designer used for every letter's
    /// `X/Background` silhouette (per PDF §1, page 2). Consumed by both the
    /// empty-state hero and the card backdrop.
    ///
    /// - Parameters:
    ///   - base: the letter's single-outline rotation path (usually
    ///     `rotationPaths(for: letter).first`).
    ///   - center: rotation origin, in the same coordinate space as `base`.
    ///     Default `(190, 190)` matches the 380×380 viewBox the outlines ship in.
    ///   - stepDegrees: angle between successive copies. Default `5°` (72 steps).
    public static func swirlPaths(
        from base: Path?,
        center: CGPoint = CGPoint(x: 190, y: 190),
        stepDegrees: Double = 5.0
    ) -> [Path] {
        guard let base else { return [] }
        let stepCount = Int(360.0 / stepDegrees)
        return (0..<stepCount).map { i in
            let radians = Double(i) * stepDegrees * .pi / 180.0
            let t = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: radians)
                .translatedBy(x: -center.x, y: -center.y)
            return base.applying(t)
        }
    }
}
