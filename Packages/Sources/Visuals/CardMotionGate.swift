import SwiftUI
import CoreModels

/// Hold the complete rendered pose during sheet movement, then rejoin the live
/// stream gradually. Tracking continues independently of this rendering gate.
public struct CardMotionGate<Content: View>: View {
    private let attitude: DeviceAttitude
    private let paused: Bool
    private let content: (DeviceAttitude) -> Content
    @Environment(\.windowSceneProjection) private var projection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rendered: CardMotionPose?
    @State private var livePose = LiveCardMotionPose()
    @State private var resumeProgress = 0.0
    @State private var resumeGeneration = 0

    public init(attitude: DeviceAttitude, paused: Bool,
                @ViewBuilder content: @escaping (DeviceAttitude) -> Content) {
        self.attitude = attitude
        self.paused = paused
        self.content = content
    }

    private var incoming: CardMotionPose {
        CardMotionPose(attitude: attitude, projection: projection)
    }

    public var body: some View {
        // Live motion goes straight to the card. Do not copy every camera
        // update through SwiftUI state and trigger another list render.
        let start = paused ? livePose.renderedValue ?? rendered ?? livePose.value ?? incoming : rendered ?? incoming
        return CardMotionSurface(start: start,
                          target: paused ? start : incoming,
                          progress: rendered == nil || paused ? 0 : resumeProgress,
                          mailbox: livePose,
                          content: content)
            .onChange(of: incoming, initial: true) { _, value in
                // Hold the last visible pose before a suspended tracker clears
                // its input; do not capture that cleared pose as the freeze.
                if paused && rendered == nil { rendered = livePose.renderedValue ?? livePose.value ?? value }
                livePose.value = value
            }
            .onChange(of: paused) { _, value in
                resumeGeneration += 1
                let generation = resumeGeneration
                if value {
                    rendered = livePose.renderedValue ?? rendered ?? livePose.value ?? incoming
                    resumeProgress = 0
                    return
                }
                guard rendered != nil else { return }
                guard !reduceMotion else { rendered = nil; return }
                // Share SwiftUI's render cadence with the zoom transition;
                // a separate sleeping task used to publish a second pose
                // update every 16 ms while the list was already redrawing.
                withAnimation(.easeInOut(duration: 0.35), completionCriteria: .removed) {
                    resumeProgress = 1
                } completion: {
                    if generation == resumeGeneration && !paused {
                        rendered = nil
                    }
                }
            }
    }
}

private struct CardMotionSurface<Content: View>: View, Animatable {
    let start: CardMotionPose
    let target: CardMotionPose
    var progress: Double
    let mailbox: LiveCardMotionPose
    let content: (DeviceAttitude) -> Content

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let pose = start.interpolated(to: target, progress: progress)
        return content(pose.attitude)
            .environment(\.windowSceneProjection, pose.projection)
            .onChange(of: pose, initial: true) { _, value in mailbox.renderedValue = value }
    }
}

/// Input mailbox; updates do not invalidate SwiftUI while motion is held.
@MainActor
private final class LiveCardMotionPose {
    var value: CardMotionPose?
    var renderedValue: CardMotionPose?
}

struct CardMotionPose: Equatable {
    let attitude: DeviceAttitude
    let projection: WindowSceneProjection?

    func interpolated(to target: Self, progress: Double) -> Self {
        let t = max(0, min(1, progress))
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        func position(_ a: ViewerPosition, _ b: ViewerPosition) -> ViewerPosition {
            ViewerPosition(x: mix(a.x, b.x), y: mix(a.y, b.y), distance: mix(a.distance, b.distance))
        }
        let scene: WindowSceneProjection?
        if let a = projection, let b = target.projection {
            scene = WindowSceneProjection(
                eye: position(a.eye, b.eye), reference: position(a.reference, b.reference),
                backingDepthMeters: mix(a.backingDepthMeters, b.backingDepthMeters),
                spacing: mix(a.spacing, b.spacing), screenWidthMeters: mix(a.screenWidthMeters, b.screenWidthMeters),
                viewport: b.viewport, reverseGuillocheDepthOrder: b.reverseGuillocheDepthOrder,
                cardCenteredReference: b.cardCenteredReference,
                cardCenteredReferenceWeight: mix(a.cardCenteredReferenceWeight, b.cardCenteredReferenceWeight))
        } else if let value = target.projection ?? projection {
            // If only one view uses face tracking, enter or leave perspective
            // through zero depth instead of changing rendering mode abruptly.
            let depth = value.backingDepthMeters * (target.projection == nil ? 1 - t : t)
            scene = t == 1 && target.projection == nil ? nil : WindowSceneProjection(
                eye: value.eye, reference: value.reference, backingDepthMeters: depth,
                spacing: value.spacing, screenWidthMeters: value.screenWidthMeters,
                viewport: value.viewport, reverseGuillocheDepthOrder: value.reverseGuillocheDepthOrder,
                cardCenteredReference: value.cardCenteredReference,
                cardCenteredReferenceWeight: value.cardCenteredReferenceWeight)
        } else {
            scene = nil
        }
        return Self(attitude: DeviceAttitude(pitch: mix(attitude.pitch, target.attitude.pitch),
                                            roll: mix(attitude.roll, target.attitude.roll)), projection: scene)
    }
}
