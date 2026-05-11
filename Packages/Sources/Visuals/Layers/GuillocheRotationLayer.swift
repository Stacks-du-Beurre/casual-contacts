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

    static let nativeViewBoxSide: CGFloat = 380

    public init(
        paths: [Path],
        tint: Color = CCDesign.Colors.L4,
        attitude: DeviceAttitude = .zero,
        usage: Usage = .card,
        reveal: Double = 1.0
    ) {
        self.paths = paths
        self.tint = tint
        self.attitude = attitude
        self.usage = usage
        self.reveal = reveal
    }

    /// Stroke opacity, sourced from the per-usage tuning slider so the dev
    /// panel can dial card vs. empty-state independently.
    private var opacity: Double {
        switch usage {
        case .card: tuning.cardOpacity
        case .emptyState: tuning.emptyStateOpacity
        }
    }

    public var body: some View {
        // `Color.clear` is flex-flex, so this layer reports the parent ZStack's
        // proposed size upward — no size leak from the fixed render child. The
        // Canvas overlay is larger than the 380×380 SVG viewBox by the viewBox
        // diagonal, so rotating the full filigree cannot crop against its own
        // render texture. Smaller card callers still crop at their intentional
        // outer `.clipped()` boundary.
        let renderSide = Self.rotatingRenderSide(forNativeSide: Self.nativeViewBoxSide)
        Color.clear
            .overlay {
                // Rasterize the 72-path stroke pass into a single Metal-backed
                // texture once the stagger has finished. While revealing, skip
                // `drawingGroup` so per-path opacity can animate smoothly.
                Group {
                    if reveal >= 1.0 {
                        canvasContent
                            .frame(width: renderSide, height: renderSide)
                            .drawingGroup(opaque: false)
                    } else {
                        canvasContent
                            .frame(width: renderSide, height: renderSide)
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
        Canvas { context, size in
            guard reveal > 0 else { return }
            context.translateBy(
                x: Self.nativeViewBoxOffset(inRenderSide: size.width, nativeSide: Self.nativeViewBoxSide),
                y: Self.nativeViewBoxOffset(inRenderSide: size.height, nativeSide: Self.nativeViewBoxSide)
            )
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

    static func rotatingRenderSide(forNativeSide nativeSide: CGFloat) -> CGFloat {
        (nativeSide * CGFloat(2.0.squareRoot())).rounded(.up)
    }

    static func nativeViewBoxOffset(inRenderSide renderSide: CGFloat, nativeSide: CGFloat) -> CGFloat {
        max(0, (renderSide - nativeSide) / 2)
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
