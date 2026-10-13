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
        let pose = rendered ?? (paused ? livePose.value ?? incoming : incoming)
        content(pose.attitude)
            .environment(\.windowSceneProjection, pose.projection)
            .onChange(of: incoming, initial: true) { _, value in
                livePose.value = value
                if paused && rendered == nil { rendered = value }
            }
            .onChange(of: paused) { _, value in
                if value { rendered = rendered ?? livePose.value ?? incoming }
            }
            .task(id: paused) {
                guard !paused, let start = rendered else { return }
                guard !reduceMotion else { rendered = nil; return }
                let clock = ContinuousClock()
                let began = clock.now
                while !Task.isCancelled {
                    let elapsed = began.duration(to: clock.now)
                    let seconds = Double(elapsed.components.seconds)
                        + Double(elapsed.components.attoseconds) / 1e18
                    let t = min(1, seconds / 0.35)
                    if let latest = livePose.value {
                        rendered = start.interpolated(to: latest, progress: t * t * (3 - 2 * t))
                    }
                    if t >= 1 {
                        rendered = nil
                        break
                    }
                    do { try await Task.sleep(for: .milliseconds(16)) }
                    catch { break }
                }
            }
    }
}

/// Input mailbox; updates do not invalidate SwiftUI while motion is held.
@MainActor
private final class LiveCardMotionPose {
    var value: CardMotionPose?
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
                cardCenteredReference: b.cardCenteredReference)
        } else if let value = target.projection ?? projection {
            // If only one view uses face tracking, enter or leave perspective
            // through zero depth instead of changing rendering mode abruptly.
            let depth = value.backingDepthMeters * (target.projection == nil ? 1 - t : t)
            scene = t == 1 && target.projection == nil ? nil : WindowSceneProjection(
                eye: value.eye, reference: value.reference, backingDepthMeters: depth,
                spacing: value.spacing, screenWidthMeters: value.screenWidthMeters,
                viewport: value.viewport, reverseGuillocheDepthOrder: value.reverseGuillocheDepthOrder,
                cardCenteredReference: value.cardCenteredReference)
        } else {
            scene = nil
        }
        return Self(attitude: DeviceAttitude(pitch: mix(attitude.pitch, target.attitude.pitch),
                                            roll: mix(attitude.roll, target.attitude.roll)), projection: scene)
    }
}
