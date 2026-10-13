#if os(iOS)
import SwiftUI
import AVFoundation
import ARKit
import CoreModels
import Services
import Visuals
import FeatureDetail
import FeatureSettings
import DesignSystem

struct FaceSceneHost<Content: View>: View {
    let listVisible: Bool
    let expandedVisible: Bool
    let attitude: DeviceAttitude
    @Binding var firstCardCameraOffer: Bool
    let content: (FaceParallaxController, WindowSceneProjection?, WindowSceneProjection?, Binding<Bool>) -> Content
    @AppStorage("FaceScene.listEnabled") private var listEnabled = false
    @AppStorage("FaceScene.expandedEnabled") private var expandedEnabled = false
    @AppStorage("FaceScene.cameraOfferSeen") private var cameraOfferSeen = false
    @AppStorage("FaceScene.cameraEnabled") private var cameraEnabled = false
    @State private var cameraAuthorization = Self.currentCameraAuthorization
    @State private var showingCameraExplanation = false
    @State private var cameraPermissionPending = false
    @State private var dismissCameraModal: (() -> Void)?
    @State private var tracker = FaceParallaxController()
    @State private var showingSceneSettings = ProcessInfo.processInfo.arguments.contains("-ScreenshotSceneSettings")
    @AppStorage("FaceScene.backingDepthMM") private var backingDepthMM = 60.0
    @AppStorage("FaceScene.layerSpacing") private var layerSpacing = 1.0
    @AppStorage("FaceScene.smoothingMS") private var smoothingMS = 35.0
    @AppStorage("FaceScene.screenWidthMM") private var screenWidthMM = 66.6
    @AppStorage("FaceScene.cameraHeightMM") private var cameraHeightMM = 65.0
    @AppStorage("FaceScene.savedPreset") private var savedPreset = ""
    @Bindable private var blendTuning = CardBlendTuning.shared
    @Environment(\.colorScheme) private var scheme
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content(tracker, listEnabled ? windowProjection(cardCentered: true) : nil,
                expandedEnabled ? windowProjection(cardCentered: false) : nil, $showingSceneSettings)
        .sheet(isPresented: $showingSceneSettings) { sceneSettings }
        .background {
            CameraModalPresenter(isPresented: showingCameraExplanation && !showingSceneSettings,
                                 setDismissAction: { dismissCameraModal = $0 },
                                 onDismissed: cameraModalDidDismiss) { cameraExplanation }
        }
        .onChange(of: firstCardCameraOffer) { _, requested in
            guard requested else { return }
            firstCardCameraOffer = false
            guard !cameraOfferSeen else { return }
            cameraOfferSeen = true
            guard supportsFaceTracking, cameraAuthorization == .authorized || cameraAuthorization == .notDetermined else { return }
            setCameraExplanationPresented(true)
        }
        .onAppear {
            updateTracking()
            if savedPreset.isEmpty { saveScenePreset() }
        }
        .task(id: scenePhase) {
            #if DEBUG
            guard scenePhase == .active,
                  ProcessInfo.processInfo.arguments.contains("-ScreenshotMode"),
                  ProcessInfo.processInfo.arguments.contains("-ScreenshotCameraExplanation"),
                  !showingSceneSettings else { return }
            // Let the app launch transition finish before demonstrating the home dialog.
            do { try await Task.sleep(for: .seconds(1.5)) }
            catch { return }
            setCameraExplanationPresented(true)
            #endif
        }
        .onChange(of: attitude) { _, value in tracker.fallback = value }
        .onChange(of: scenePhase) { _, _ in
            cameraAuthorization = Self.currentCameraAuthorization
            updateTracking()
        }
        .onChange(of: cameraEnabled) { _, _ in updateTracking() }
        .onChange(of: reduceMotion) { _, _ in updateTracking() }
        .onChange(of: listVisible) { _, _ in updateTracking() }
        .onChange(of: expandedVisible) { _, _ in updateTracking() }
        .onChange(of: listEnabled) { _, _ in updateTracking() }
        .onChange(of: expandedEnabled) { _, _ in updateTracking() }
        .onChange(of: cameraHeightMM) { _, value in tracker.setCameraHeight(value / 1000) }
        .onChange(of: smoothingMS) { _, value in tracker.smoothingSeconds = value / 1000 }
        .onDisappear {
            // A full-screen cover hides the list without ending its shared session.
            if !expandedVisible { tracker.setActive(false) }
        }
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
            ScrollView {
                VStack(spacing: 24) {
                SettingsGroup(title: ModuleLocalization.string("Enable 3D simulation", locale: locale)) {
                    SettingsToggleRow(label: ModuleLocalization.string("Cards in the list", locale: locale), isOn: $listEnabled)
                    SettingsDivider()
                    SettingsToggleRow(label: ModuleLocalization.string("Expanded card", locale: locale), isOn: $expandedEnabled)
                    SettingsDivider()
                    ModuleLocalization.text(tracker.status, locale: locale).font(CCDesign.Typography.caption2).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    ModuleLocalization.text("Uses gyro motion by default. Optional camera mode runs only while an enabled card view is visible.", locale: locale).font(CCDesign.Typography.caption2).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    privacyPolicyLink("Privacy policy").padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
                SettingsGroup(title: ModuleLocalization.string("Camera for face perspective", locale: locale)) {
                    SettingsToggleRow(label: ModuleLocalization.string("Use camera for face perspective", locale: locale), isOn: Binding(
                        get: { cameraEnabled && cameraAuthorization == .authorized },
                        set: { value in
                            if !value { cameraEnabled = false }
                            else if cameraAuthorization == .authorized || cameraAuthorization == .notDetermined { setCameraExplanationPresented(true) }
                        }
                    ))
                    .disabled(cameraAuthorization == .denied || cameraAuthorization == .restricted || !supportsFaceTracking)
                    ModuleLocalization.text("Gyro motion works without camera access. Camera mode adds perspective from your face and eye position; it does not identify you.", locale: locale)
                        .font(CCDesign.Typography.caption2).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    if cameraAuthorization == .denied {
                        Button(ModuleLocalization.string("Enable camera in Settings", locale: locale)) {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        ModuleLocalization.text("In Settings, turn on Camera, then return here and enable face perspective.", locale: locale).font(CCDesign.Typography.caption2).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    } else if cameraAuthorization == .restricted {
                        ModuleLocalization.text("Camera access is restricted by your device settings.", locale: locale).font(CCDesign.Typography.caption2).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    } else if !supportsFaceTracking {
                        ModuleLocalization.text("Face perspective is unavailable on this device. Gyro motion is still available.", locale: locale).font(CCDesign.Typography.caption2).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                SettingsGroup(title: ModuleLocalization.string("Scene", locale: locale)) {
                    parameter("Backing depth", value: $backingDepthMM, range: 0...150, step: 5, unit: "mm")
                    parameter("Layer spacing", value: $layerSpacing, range: 0.5...2, step: 0.1, unit: "")
                    ModuleLocalization.text("The rotation guilloche stays on the deepest blend layer.", locale: locale)
                        .font(CCDesign.Typography.caption2).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    ModuleLocalization.text("The backing sits behind the phone screen. Text stays on the front surface.", locale: locale)
                        .font(CCDesign.Typography.caption2).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
                SettingsGroup(title: ModuleLocalization.string("Tracking", locale: locale)) {
                    parameter("Smoothing", value: $smoothingMS, range: 10...150, step: 5, unit: "ms")
                    if let eye = tracker.eyePosition {
                        Text(ModuleLocalization.string("Eye distance: %d mm", locale: locale, Int(eye.distance * 1000)))
                    }
                    Button(ModuleLocalization.string("Reset tracking", locale: locale)) { tracker.recenter() }
                }
                SettingsGroup(title: ModuleLocalization.string("Screen calibration", locale: locale)) {
                    ModuleLocalization.text("The neutral viewpoint is fixed at screen center, 400 mm away. Your face position at startup does not change it.", locale: locale).font(CCDesign.Typography.caption2).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    parameter("Screen width", value: $screenWidthMM, range: 55...90, step: 0.5, unit: "mm")
                    parameter("Camera above screen center", value: $cameraHeightMM, range: 40...80, step: 1, unit: "mm")
                    ModuleLocalization.text("Defaults approximate iPhone 17 Pro. These are physical measurements, not effect strength.", locale: locale)
                        .font(CCDesign.Typography.caption2).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
                SettingsGroup(title: ModuleLocalization.string("Presets", locale: locale)) {
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
                .padding(.vertical, 20)
            }
            .font(CCDesign.Typography.description)
            .tracking(CCDesign.Typography.Tracking.description)
            .foregroundStyle(SettingsPalette.label(scheme))
            .background(SettingsPalette.sheetBackground(scheme))
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-ScreenshotCameraExplanation") { setCameraExplanationPresented(true) }
                #endif
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Spacer()
                    ModuleLocalization.text("3D scene", locale: locale).textCase(.uppercase).font(CCDesign.Typography.headline).tracking(CCDesign.Typography.Tracking.headline)
                    Spacer()
                    Button(ModuleLocalization.string("Done", locale: locale)) { showingSceneSettings = false }.font(CCDesign.Typography.description)
                }.padding(.horizontal, 16).frame(height: 56).background(SettingsPalette.sheetBackground(scheme))
            }
            .toolbar(.hidden, for: .navigationBar)
            .tint(SettingsPalette.label(scheme))
        }
        .background {
            CameraModalPresenter(isPresented: showingCameraExplanation,
                                 setDismissAction: { dismissCameraModal = $0 },
                                 onDismissed: cameraModalDidDismiss) { cameraExplanation }
        }
        .presentationCornerRadius(12)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(SettingsPalette.sheetBackground(scheme))
    }

    private static var currentCameraAuthorization: AVAuthorizationStatus {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ScreenshotMode") &&
            ProcessInfo.processInfo.arguments.contains("-ScreenshotCameraDenied") { return .denied }
        #endif
        return AVCaptureDevice.authorizationStatus(for: .video)
    }

    private var supportsFaceTracking: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ScreenshotMode") { return true }
        #endif
        return ARFaceTrackingConfiguration.isSupported
    }

    private func cameraModalDidDismiss() {
        showingCameraExplanation = false
        dismissCameraModal = nil
        requestCameraPermissionIfPending()
    }

    private func requestCameraPermissionIfPending() {
        guard cameraPermissionPending else { return }
        cameraPermissionPending = false
        Task {
            let allowed = cameraAuthorization == .authorized ? true : await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorization = Self.currentCameraAuthorization
            cameraEnabled = allowed
            if allowed { listEnabled = true; expandedEnabled = true }
            updateTracking()
        }
    }

    private func setCameraExplanationPresented(_ presented: Bool) {
        showingCameraExplanation = presented
    }

    private var cameraExplanation: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            GeometryReader { geometry in
                ScrollView {
                    VStack {
                        VStack(alignment: .leading, spacing: 18) {
                            ModuleLocalization.text("CAMERA PERSPECTIVE", locale: locale)
                                .font(CCDesign.Typography.headline)
                                .tracking(CCDesign.Typography.Tracking.headline)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                            ModuleLocalization.text("Bring your cards to life with 3D depth that responds as you move. The front camera uses your eye position and distance to create the effect.", locale: locale)
                            ModuleLocalization.text("Face data stays in device memory, never saved, shared, or used to identify you.", locale: locale)
                            ModuleLocalization.text("Camera is optional. Decline for gyro motion; change access in 3D scene.", locale: locale)
                            privacyPolicyLink("Privacy policy — Face data and TrueDepth")
                            Button(ModuleLocalization.string(cameraAuthorization == .authorized ? "Enable face perspective" : "Continue to camera permission", locale: locale)) {
                                cameraOfferSeen = true
                                cameraPermissionPending = true
                                dismissCameraModal?()
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .foregroundStyle(SettingsPalette.sheetBackground(scheme))
                            .background(SettingsPalette.label(scheme))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .font(CCDesign.Typography.description)
                        .tracking(CCDesign.Typography.Tracking.description)
                        .foregroundStyle(SettingsPalette.label(scheme))
                        .multilineTextAlignment(.leading)
                        .accessibilityAddTraits(.isModal)
                        .padding(22)
                        .frame(maxWidth: 360)
                        .background(SettingsPalette.rowBackground(scheme))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(SettingsPalette.border(scheme), lineWidth: 1))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 28)
                    }
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
            }
        }
    }

    private func privacyPolicyLink(_ title: String) -> some View {
        Button {
            UIApplication.shared.open(ModuleLocalization.privacyPolicyURL(locale: locale))
        } label: {
            ModuleLocalization.text(title, locale: locale).underline()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
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
        }.padding(16)
    }

    private func saveScenePreset() {
        let values = [backingDepthMM, layerSpacing, smoothingMS, screenWidthMM, cameraHeightMM]
        if let data = try? JSONEncoder().encode(values), let text = String(data: data, encoding: .utf8) {
            savedPreset = text
        }
    }

    private func updateTracking() {
        tracker.usesCamera = cameraEnabled && cameraAuthorization == .authorized
        tracker.fallback = attitude
        tracker.smoothingSeconds = smoothingMS / 1000
        tracker.setCameraHeight(cameraHeightMM / 1000)
        let enabled = expandedVisible ? expandedEnabled : (listVisible && listEnabled)
        tracker.setActive(scenePhase == .active && !reduceMotion && (listVisible || expandedVisible))
        if tracker.enabled != enabled { tracker.setEnabled(enabled) }
    }
}
#endif
