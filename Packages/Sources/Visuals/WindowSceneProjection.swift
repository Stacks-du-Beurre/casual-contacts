import CoreModels
import SwiftUI

public struct WindowSceneProjection: Equatable, Sendable {
    public let eye: ViewerPosition
    public let reference: ViewerPosition
    public let backingDepthMeters: Double
    public let spacing: Double
    public let screenWidthMeters: Double
    public let viewport: CGSize
    public let reverseGuillocheDepthOrder: Bool
    public let cardCenteredReference: Bool

    public init(eye: ViewerPosition, reference: ViewerPosition, backingDepthMeters: Double,
                spacing: Double, screenWidthMeters: Double, viewport: CGSize,
                reverseGuillocheDepthOrder: Bool = false, cardCenteredReference: Bool = false) {
        self.eye = eye
        self.reference = reference
        self.backingDepthMeters = backingDepthMeters
        self.spacing = spacing
        self.screenWidthMeters = screenWidthMeters
        self.viewport = viewport
        self.reverseGuillocheDepthOrder = reverseGuillocheDepthOrder
        self.cardCenteredReference = cardCenteredReference
    }
}

private struct WindowCardFrameKey: EnvironmentKey {
    static let defaultValue: CGRect? = nil
}

private struct WindowSceneProjectionKey: EnvironmentKey {
    static let defaultValue: WindowSceneProjection? = nil
}
private struct WindowCardSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = .zero
}
private struct LiveWindowGeometryKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var windowCardSize: CGSize {
        get { self[WindowCardSizeKey.self] }
        set { self[WindowCardSizeKey.self] = newValue }
    }
    var liveWindowGeometry: Bool {
        get { self[LiveWindowGeometryKey.self] }
        set { self[LiveWindowGeometryKey.self] = newValue }
    }
    var windowCardFrame: CGRect? {
        get { self[WindowCardFrameKey.self] }
        set { self[WindowCardFrameKey.self] = newValue }
    }
    var windowSceneProjection: WindowSceneProjection? {
        get { self[WindowSceneProjectionKey.self] }
        set { self[WindowSceneProjectionKey.self] = newValue }
    }
}

private struct WindowDepthModifier: ViewModifier {
    let fraction: Double
    @Environment(\.windowSceneProjection) private var scene
    @Environment(\.windowCardFrame) private var cardFrame
    @Environment(\.windowCardSize) private var cardSize
    @Environment(\.liveWindowGeometry) private var liveGeometry

    func body(content: Content) -> some View {
        if let scene {
            let depth = scene.backingDepthMeters * pow(max(0, min(1, fraction)), scene.spacing)

            content.visualEffect { view, geometry in
                let local = geometry.frame(in: .named("CardScene"))
                let resolvedFrame = liveGeometry
                    ? WindowSceneProjection.cardFrame(local: local, global: geometry.frame(in: .global), size: cardSize)
                    : cardFrame
                let center = resolvedFrame.map { CGRect(x: $0.minX + local.minX, y: $0.minY + local.minY,
                                                   width: local.width, height: local.height) }
                    ?? geometry.frame(in: .global)
                let metersPerPoint = scene.screenWidthMeters / max(Double(scene.viewport.width), 1)
                let x = Double(center.midX - scene.viewport.width / 2) * metersPerPoint
                let y = -Double(center.midY - scene.viewport.height / 2) * metersPerPoint
                let reference = scene.reference(for: resolvedFrame ?? center)
                let projection = WindowPlaneProjection(eye: scene.eye, reference: reference, depth: depth)
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

extension WindowSceneProjection {
    nonisolated static func cardFrame(local: CGRect, global: CGRect, size: CGSize) -> CGRect {
        CGRect(x: global.minX - local.minX, y: global.minY - local.minY,
               width: size.width, height: size.height)
    }
    func reference(for frame: CGRect) -> ViewerPosition {
        guard cardCenteredReference else { return reference }
        let metersPerPoint = screenWidthMeters / max(Double(viewport.width), 1)
        return ViewerPosition(x: Double(frame.midX - viewport.width / 2) * metersPerPoint,
                              y: -Double(frame.midY - viewport.height / 2) * metersPerPoint,
                              distance: reference.distance)
    }
}
