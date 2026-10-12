import CoreModels
import SwiftUI

public struct WindowSceneProjection: Sendable {
    public let eye: ViewerPosition
    public let reference: ViewerPosition
    public let backingDepthMeters: Double
    public let spacing: Double
    public let screenWidthMeters: Double
    public let viewport: CGSize
    public let reverseGuillocheDepthOrder: Bool

    public init(eye: ViewerPosition, reference: ViewerPosition, backingDepthMeters: Double,
                spacing: Double, screenWidthMeters: Double, viewport: CGSize,
                reverseGuillocheDepthOrder: Bool = false) {
        self.eye = eye
        self.reference = reference
        self.backingDepthMeters = backingDepthMeters
        self.spacing = spacing
        self.screenWidthMeters = screenWidthMeters
        self.viewport = viewport
        self.reverseGuillocheDepthOrder = reverseGuillocheDepthOrder
    }
}

private struct WindowSceneProjectionKey: EnvironmentKey {
    static let defaultValue: WindowSceneProjection? = nil
}

public extension EnvironmentValues {
    var windowSceneProjection: WindowSceneProjection? {
        get { self[WindowSceneProjectionKey.self] }
        set { self[WindowSceneProjectionKey.self] = newValue }
    }
}

private struct WindowDepthModifier: ViewModifier {
    let fraction: Double
    @Environment(\.windowSceneProjection) private var scene

    func body(content: Content) -> some View {
        if let scene {
            let depth = scene.backingDepthMeters * pow(max(0, min(1, fraction)), scene.spacing)
            let projection = WindowPlaneProjection(eye: scene.eye, reference: scene.reference, depth: depth)
            content.visualEffect { view, geometry in
                let center = geometry.frame(in: .global)
                let metersPerPoint = scene.screenWidthMeters / max(Double(scene.viewport.width), 1)
                let x = Double(center.midX - scene.viewport.width / 2) * metersPerPoint
                let y = -Double(center.midY - scene.viewport.height / 2) * metersPerPoint
                let scale = projection?.scale ?? 1
                let dx = ((scale - 1) * x + (projection?.translationX ?? 0)) / metersPerPoint
                let dy = -((scale - 1) * y + (projection?.translationY ?? 0)) / metersPerPoint
                return view.scaleEffect(scale).offset(x: dx, y: dy)
            }
        } else {
            content
        }
    }
}

extension View {
    /// Fraction 0 is the screen surface; 1 is the backing plane. Painter order
    /// must match depth: farther planes are drawn before nearer planes.
    func windowDepth(_ fraction: Double) -> some View {
        modifier(WindowDepthModifier(fraction: fraction))
    }
}
