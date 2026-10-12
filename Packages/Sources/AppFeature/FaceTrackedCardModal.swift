#if os(iOS)
import SwiftUI
import CoreModels
import Services
import Visuals
import FeatureDetail

struct FaceTrackedCardModal: View {
    let record: Record
    let sourceFrame: CGRect
    let attitude: DeviceAttitude
    let paths: any CardPathProvider
    let photo: Image?
    let photoSize: CGSize?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void
    @State private var tracker = FaceParallaxController()
    @State private var showingSceneSettings = false
    @AppStorage("FaceScene.backingDepthMM") private var backingDepthMM = 60.0
    @AppStorage("FaceScene.layerSpacing") private var layerSpacing = 1.0
    @AppStorage("FaceScene.smoothingMS") private var smoothingMS = 35.0
    @AppStorage("FaceScene.screenWidthMM") private var screenWidthMM = 66.6
    @AppStorage("FaceScene.cameraHeightMM") private var cameraHeightMM = 65.0
    @AppStorage("FaceScene.savedPreset") private var savedPreset = ""
    @Bindable private var blendTuning = CardBlendTuning.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TappedCardModalScene(
            record: record,
            sourceFrame: sourceFrame,
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
            onRecenterFaceTracking: { tracker.recenter() },
            onSceneSettings: { showingSceneSettings = true }
        )
        .environment(\.windowSceneProjection, windowProjection)
        .sheet(isPresented: $showingSceneSettings) { sceneSettings }
        .onAppear {
            updateTracking()
            if savedPreset.isEmpty { saveScenePreset() }
        }
        .onChange(of: attitude) { _, value in tracker.fallback = value }
        .onChange(of: scenePhase) { _, _ in updateTracking() }
        .onChange(of: reduceMotion) { _, _ in updateTracking() }
        .onChange(of: smoothingMS) { _, value in tracker.smoothingSeconds = value / 1000 }
        .onDisappear { tracker.setActive(false) }
    }

    private var windowProjection: WindowSceneProjection? {
        guard !reduceMotion, tracker.enabled,
              let eye = tracker.eyePosition, let reference = tracker.referenceEye else { return nil }
        // ARKit poses use the front camera as origin. Approximate its height
        // above screen center; expose calibration instead of claiming precision.
        let height = cameraHeightMM / 1000
        return WindowSceneProjection(
            eye: ViewerPosition(
                x: blendTuning.reverseMotionDirection ? 2 * reference.x - eye.x : eye.x,
                y: (blendTuning.reverseMotionDirection ? 2 * reference.y - eye.y : eye.y) + height,
                distance: eye.distance
            ),
            reference: ViewerPosition(x: reference.x, y: reference.y + height, distance: reference.distance),
            backingDepthMeters: max(0, backingDepthMM) / 1000,
            spacing: max(0.5, min(2, layerSpacing)),
            screenWidthMeters: max(55, min(90, screenWidthMM)) / 1000,
            viewport: UIScreen.main.bounds.size,
            reverseGuillocheDepthOrder: blendTuning.reverseDepthOrder
        )
    }

    private var sceneSettings: some View {
        NavigationStack {
            Form {
                Section("Scene") {
                    parameter("Backing depth", value: $backingDepthMM, range: 0...150, step: 5, unit: "mm")
                    parameter("Layer spacing", value: $layerSpacing, range: 0.5...2, step: 0.1, unit: "")
                    Text("The rotation guilloche stays on the deepest blend layer.")
                        .font(.caption)
                    Text("The backing sits behind the phone screen. Text stays on the front surface.")
                        .font(.caption)
                }
                Section("Tracking") {
                    parameter("Smoothing", value: $smoothingMS, range: 10...150, step: 5, unit: "ms")
                    if let eye = tracker.eyePosition {
                        Text("Eye distance: \(Int(eye.distance * 1000)) mm")
                    }
                    Button("Recenter scene") { tracker.recenter() }
                }
                Section("Screen calibration") {
                    parameter("Screen width", value: $screenWidthMM, range: 55...90, step: 0.5, unit: "mm")
                    parameter("Camera above screen center", value: $cameraHeightMM, range: 40...80, step: 1, unit: "mm")
                    Text("Defaults approximate iPhone 17 Pro. These are physical measurements, not effect strength.")
                        .font(.caption)
                }
                Section("Presets") {
                    Button("Shallow · 20 mm") { backingDepthMM = 20; layerSpacing = 1; smoothingMS = 35 }
                    Button("Balanced · 60 mm") { backingDepthMM = 60; layerSpacing = 1; smoothingMS = 35 }
                    Button("Deep · 120 mm") { backingDepthMM = 120; layerSpacing = 1; smoothingMS = 35 }
                    Button("Save my preset", action: saveScenePreset)
                    if !savedPreset.isEmpty {
                        Button("Load my preset") {
                            guard let values = try? JSONDecoder().decode([Double].self, from: Data(savedPreset.utf8)),
                                  (values.count == 5 || values.count == 7), values.allSatisfy(\.isFinite) else { return }
                            backingDepthMM = max(0, min(150, values[0]))
                            layerSpacing = max(0.5, min(2, values[1]))
                            smoothingMS = max(10, min(150, values[2]))
                            screenWidthMM = max(55, min(90, values[3]))
                            cameraHeightMM = max(40, min(80, values[4]))
                        }
                    }
                }
            }
            .navigationTitle("Scene settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingSceneSettings = false } } }
        }
    }

    private func parameter(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                           step: Double, unit: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue, specifier: "%.1f") \(unit)").monospacedDigit()
            }
            Slider(value: value, in: range, step: step) { Text(title) }
        }
    }

    private func saveScenePreset() {
        let values = [backingDepthMM, layerSpacing, smoothingMS, screenWidthMM, cameraHeightMM]
        if let data = try? JSONEncoder().encode(values), let text = String(data: data, encoding: .utf8) {
            savedPreset = text
        }
    }

    private func updateTracking() {
        tracker.fallback = attitude
        tracker.smoothingSeconds = smoothingMS / 1000
        tracker.setActive(scenePhase == .active && !reduceMotion)
    }
}
#endif
