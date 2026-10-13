#if os(iOS)
import SwiftUI
import CoreModels
import Services
import Visuals
import FeatureDetail

struct FaceSceneHost<Content: View>: View {
    let listVisible: Bool
    let expandedVisible: Bool
    let attitude: DeviceAttitude
    let content: (FaceParallaxController, WindowSceneProjection?, WindowSceneProjection?, Binding<Bool>) -> Content
    @AppStorage("FaceScene.listEnabled") private var listEnabled = false
    @AppStorage("FaceScene.expandedEnabled") private var expandedEnabled = false
    @State private var tracker = FaceParallaxController()
    @State private var showingSceneSettings = false
    @AppStorage("FaceScene.backingDepthMM") private var backingDepthMM = 60.0
    @AppStorage("FaceScene.layerSpacing") private var layerSpacing = 1.0
    @AppStorage("FaceScene.smoothingMS") private var smoothingMS = 35.0
    @AppStorage("FaceScene.screenWidthMM") private var screenWidthMM = 66.6
    @AppStorage("FaceScene.cameraHeightMM") private var cameraHeightMM = 65.0
    @AppStorage("FaceScene.savedPreset") private var savedPreset = ""
    @Bindable private var blendTuning = CardBlendTuning.shared
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content(tracker, listEnabled ? windowProjection(cardCentered: true) : nil,
                expandedEnabled ? windowProjection(cardCentered: false) : nil, $showingSceneSettings)
        .sheet(isPresented: $showingSceneSettings) { sceneSettings }
        .onAppear {
            updateTracking()
            if savedPreset.isEmpty { saveScenePreset() }
        }
        .onChange(of: attitude) { _, value in tracker.fallback = value }
        .onChange(of: scenePhase) { _, _ in updateTracking() }
        .onChange(of: reduceMotion) { _, _ in updateTracking() }
        .onChange(of: listVisible) { _, _ in updateTracking() }
        .onChange(of: expandedVisible) { _, _ in updateTracking() }
        .onChange(of: listEnabled) { _, _ in updateTracking() }
        .onChange(of: expandedEnabled) { _, _ in updateTracking() }
        .onChange(of: cameraHeightMM) { _, value in tracker.setCameraHeight(value / 1000) }
        .onChange(of: smoothingMS) { _, value in tracker.smoothingSeconds = value / 1000 }
        .onDisappear { tracker.setActive(false) }
    }

    private func windowProjection(cardCentered: Bool) -> WindowSceneProjection? {
        guard !reduceMotion, tracker.enabled,
              let eye = tracker.eyePosition else { return nil }
        // ARKit poses use the front camera as origin. Approximate its height
        // above screen center; expose calibration instead of claiming precision.
        let height = cameraHeightMM / 1000
        return WindowSceneProjection(
            eye: ViewerPosition(
                x: blendTuning.reverseMotionDirection ? -eye.x : eye.x,
                y: blendTuning.reverseMotionDirection ? -(eye.y + height) : eye.y + height,
                distance: eye.distance
            ),
            reference: ViewerPosition(x: 0, y: 0, distance: 0.4),
            backingDepthMeters: max(0, backingDepthMM) / 1000 * tracker.sceneActivation,
            spacing: max(0.5, min(2, layerSpacing)),
            screenWidthMeters: max(55, min(90, screenWidthMM)) / 1000,
            viewport: UIScreen.main.bounds.size,
            reverseGuillocheDepthOrder: blendTuning.reverseDepthOrder,
            cardCenteredReference: cardCentered
        )
    }

    private var sceneSettings: some View {
        NavigationStack {
            Form {
                Section(ModuleLocalization.string("Enable 3D simulation", locale: locale)) {
                    Toggle(ModuleLocalization.string("Cards in the list", locale: locale), isOn: $listEnabled)
                    Toggle(ModuleLocalization.string("Expanded card", locale: locale), isOn: $expandedEnabled)
                    ModuleLocalization.text(tracker.status, locale: locale).font(.caption)
                    ModuleLocalization.text("Uses the front camera while an enabled card view is visible. Frames are not saved or uploaded.", locale: locale).font(.caption)
                    Link(ModuleLocalization.string("Privacy policy", locale: locale), destination: URL(string: "https://casualcontacts.app/privacy.html")!)
                }
                Section(ModuleLocalization.string("Scene", locale: locale)) {
                    parameter("Backing depth", value: $backingDepthMM, range: 0...150, step: 5, unit: "mm")
                    parameter("Layer spacing", value: $layerSpacing, range: 0.5...2, step: 0.1, unit: "")
                    ModuleLocalization.text("The rotation guilloche stays on the deepest blend layer.", locale: locale)
                        .font(.caption)
                    ModuleLocalization.text("The backing sits behind the phone screen. Text stays on the front surface.", locale: locale)
                        .font(.caption)
                }
                Section(ModuleLocalization.string("Tracking", locale: locale)) {
                    parameter("Smoothing", value: $smoothingMS, range: 10...150, step: 5, unit: "ms")
                    if let eye = tracker.eyePosition {
                        ModuleLocalization.text("Eye distance: \(Int(eye.distance * 1000)) mm", locale: locale)
                    }
                    Button(ModuleLocalization.string("Reset tracking", locale: locale)) { tracker.recenter() }
                }
                Section(ModuleLocalization.string("Screen calibration", locale: locale)) {
                    ModuleLocalization.text("The neutral viewpoint is fixed at screen center, 400 mm away. Your face position at startup does not change it.", locale: locale).font(.caption)
                    parameter("Screen width", value: $screenWidthMM, range: 55...90, step: 0.5, unit: "mm")
                    parameter("Camera above screen center", value: $cameraHeightMM, range: 40...80, step: 1, unit: "mm")
                    ModuleLocalization.text("Defaults approximate iPhone 17 Pro. These are physical measurements, not effect strength.", locale: locale)
                        .font(.caption)
                }
                Section(ModuleLocalization.string("Presets", locale: locale)) {
                    Button(ModuleLocalization.string("Shallow · 20 mm", locale: locale)) { backingDepthMM = 20; layerSpacing = 1; smoothingMS = 35 }
                    Button(ModuleLocalization.string("Balanced · 60 mm", locale: locale)) { backingDepthMM = 60; layerSpacing = 1; smoothingMS = 35 }
                    Button(ModuleLocalization.string("Deep · 120 mm", locale: locale)) { backingDepthMM = 120; layerSpacing = 1; smoothingMS = 35 }
                    Button(ModuleLocalization.string("Save my preset", locale: locale), action: saveScenePreset)
                    if !savedPreset.isEmpty {
                        Button(ModuleLocalization.string("Load my preset", locale: locale)) {
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
            .navigationTitle(ModuleLocalization.string("3D scene", locale: locale))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(ModuleLocalization.string("Done", locale: locale)) { showingSceneSettings = false } } }
        }
    }

    private func parameter(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                           step: Double, unit: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                ModuleLocalization.text(title, locale: locale)
                Spacer()
                Text(verbatim: String(format: "%.1f %@", locale: locale, value.wrappedValue, unit)).monospacedDigit()
            }
            Slider(value: value, in: range, step: step) { ModuleLocalization.text(title, locale: locale) }
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
        tracker.setCameraHeight(cameraHeightMM / 1000)
        let enabled = expandedVisible ? expandedEnabled : (listVisible && listEnabled)
        tracker.setActive(scenePhase == .active && !reduceMotion && (listVisible || expandedVisible))
        if tracker.enabled != enabled { tracker.setEnabled(enabled) }
    }
}
#endif
