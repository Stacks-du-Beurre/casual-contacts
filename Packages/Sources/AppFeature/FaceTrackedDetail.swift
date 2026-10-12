#if os(iOS)
import SwiftUI
import CoreModels
import Services
import Visuals
import FeatureDetail

struct FaceTrackedDetail: View {
    let record: Record
    let attitude: DeviceAttitude
    let paths: any CardPathProvider
    let photo: Image?
    let photoSize: CGSize?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void
    @State private var tracker = FaceParallaxController()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LargeDetailScene(
            record: record,
            attitude: reduceMotion ? .zero : (tracker.enabled ? tracker.renderingAttitude : attitude),
            paths: paths,
            photo: photo,
            photoSize: photoSize,
            onEdit: onEdit,
            onDelete: onDelete,
            onDismiss: onDismiss,
            faceTrackingEnabled: tracker.enabled,
            faceTrackingStatus: tracker.status,
            onToggleFaceTracking: { tracker.setEnabled(!tracker.enabled) },
            onRecenterFaceTracking: { tracker.recenter() }
        )
        .onAppear { updateTracking() }
        .onChange(of: attitude) { _, value in tracker.fallback = value }
        .onChange(of: scenePhase) { _, _ in updateTracking() }
        .onChange(of: reduceMotion) { _, _ in updateTracking() }
        .onDisappear { tracker.setActive(false) }
    }

    private func updateTracking() {
        tracker.fallback = attitude
        tracker.setActive(scenePhase == .active && !reduceMotion)
    }
}
#endif
