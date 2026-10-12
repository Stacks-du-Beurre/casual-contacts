import CoreModels
import SwiftUI

/// A single cached mirrored repeat cell fills the complete card. Projection
/// moves the pattern coordinates, rather than hundreds of view instances.
struct WindowGradientBackdrop: View {
    let timeOfDay: TimeOfDay
    let scene: WindowSceneProjection
    @Environment(\.windowCardFrame) private var cardFrame
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geometry in
            let frame = cardFrame ?? geometry.frame(in: .global)
            let size = geometry.size
            let tile = GradientLayer.backdrop(for: timeOfDay)
                .mirroredTile(aspect: size.width / max(size.height, 1), blend: !reduceTransparency)
            let projection = WindowPlaneProjection(eye: scene.eye, reference: scene.reference(for: frame),
                                                   depth: scene.backingDepthMeters)
            let metersPerPoint = scene.screenWidthMeters / max(Double(scene.viewport.width), 1)
            let x = Double(frame.midX - scene.viewport.width / 2) * metersPerPoint
            let y = -Double(frame.midY - scene.viewport.height / 2) * metersPerPoint
            let scale = projection?.scale ?? 1
            let dx = ((scale - 1) * x + (projection?.translationX ?? 0)) / metersPerPoint
            let dy = -((scale - 1) * y + (projection?.translationY ?? 0)) / metersPerPoint
            if let tile {
                Canvas { context, canvasSize in
                    let totalScale = scale * 1.8
                    let origin = CGPoint(x: canvasSize.width / 2 + dx - canvasSize.width * totalScale / 2,
                                         y: canvasSize.height / 2 + dy - canvasSize.height * totalScale / 2)
                    context.fill(Path(CGRect(origin: .zero, size: canvasSize)),
                                 with: .tiledImage(tile.image, origin: origin,
                                                  scale: canvasSize.width * totalScale / tile.tileWidth))
                }
            } else {
                GradientLayer(timeOfDay: timeOfDay, attitude: .zero, mode: .balancedAtRest)
            }
        }
        .accessibilityHidden(true)
    }
}
