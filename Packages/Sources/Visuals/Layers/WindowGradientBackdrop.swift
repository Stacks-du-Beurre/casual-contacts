import CoreModels
import SwiftUI

/// A fixed mirror-tiled backing plane. Every tile keeps the original crop;
/// the central tile retains the previous overscan and perspective movement.
struct WindowGradientBackdrop: View {
    let timeOfDay: TimeOfDay
    let scene: WindowSceneProjection

    var body: some View {
        GeometryReader { geometry in
            // Keep neighboring tiles mounted before a tracking handoff;
            // there is no threshold that switches the backing renderer.
            ZStack {
                ForEach(-8...8, id: \.self) { row in
                    ForEach(-8...8, id: \.self) { column in
                        GradientLayer(timeOfDay: timeOfDay, attitude: .zero, mode: .balancedAtRest)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(x: column.isMultiple(of: 2) ? 1 : -1,
                                         y: row.isMultiple(of: 2) ? 1 : -1)
                            .offset(x: CGFloat(column) * geometry.size.width,
                                    y: CGFloat(row) * geometry.size.height)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .scaleEffect(1.8)
            .windowDepth(1)
        }
        .accessibilityHidden(true)
    }
}
