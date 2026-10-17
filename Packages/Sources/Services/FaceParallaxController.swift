#if os(iOS)
import ARKit
import AVFoundation
import CoreModels
import CoreMotion
import Observation
import UIKit

/// Runs gyro motion for enabled card views; camera use requires a separate opt-in.
@MainActor @Observable
public final class FaceParallaxController: NSObject, @preconcurrency ARSessionDelegate {
    public private(set) var attitude: DeviceAttitude = .zero
    public private(set) var status = "Face parallax off"
    public private(set) var enabled = false
    public var usesCamera = false {
        didSet {
            guard usesCamera != oldValue else { return }
            stop()
            if active && enabled { start() }
        }
    }
    public var fallback: DeviceAttitude = .zero
    public var smoothingSeconds: Double = 0.035
    public private(set) var eyePosition: ViewerPosition?
    public private(set) var referenceEye: ViewerPosition?
    public private(set) var sceneActivation = 0.0
    public var renderingAttitude: DeviceAttitude { displayLink == nil ? fallback : attitude }

    @ObservationIgnored private var session = ARSession()
    @ObservationIgnored private nonisolated let cameraCadence = CameraPoseCadence()
    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var inertialViewer = InertialViewer()
    @ObservationIgnored private let orientations = GyroOrientationBuffer()
    @ObservationIgnored private let gyroQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "FaceParallax.gyro"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()
    @ObservationIgnored private var fallbackFailure: String?
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var linkTarget: DisplayLinkTarget?
    @ObservationIgnored private var projection = ViewerParallax(reference: .screenCentered(cameraHeightMeters: 0.065))
    @ObservationIgnored private var neutralReference = ViewerPosition.screenCentered(cameraHeightMeters: 0.065)
    @ObservationIgnored private var smoother = DisplayAttitudeSmoother()
    @ObservationIgnored private var target: DeviceAttitude?
    @ObservationIgnored private var targetEye: ViewerPosition?
    @ObservationIgnored private var lastFaceTime: TimeInterval = 0
    @ObservationIgnored private var lastDisplayTime: TimeInterval = 0
    @ObservationIgnored private var active = false
    @ObservationIgnored private var acquisition = SceneAcquisitionEasing()
    @ObservationIgnored private var trackingInputState = "waiting"
    #if DEBUG
    @ObservationIgnored private var diagnosticStart: TimeInterval = 0
    @ObservationIgnored private var cameraFrames = 0
    @ObservationIgnored private var displayTicks = 0
    #endif

    public override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(powerStateChanged),
                                               name: .NSProcessInfoPowerStateDidChange, object: nil)
        session.delegate = self
        session.delegateQueue = DispatchQueue(label: "FaceParallax.camera", qos: .userInteractive)
    }

    public func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        if enabled { start() } else { stop() }
    }

    public func setActive(_ active: Bool) {
        self.active = active
        if active && enabled { start() } else { stop() }
    }

    public func setCameraHeight(_ meters: Double) {
        guard meters.isFinite, (0.04...0.08).contains(meters) else { return }
        let reference = ViewerPosition.screenCentered(cameraHeightMeters: meters)
        guard reference != neutralReference else { return }
        neutralReference = reference
        projection = ViewerParallax(reference: reference)
        if referenceEye != nil { referenceEye = reference }
    }

    public func recenter() {
        projection.reset()
        inertialViewer = InertialViewer()
        target = nil
        referenceEye = nil
        status = "Finding your face"
    }

    private func start() {
        guard active, enabled, displayLink == nil else { return }
        runSession()
    }

    private func runSession() {
        PerformanceDiagnostics.shared.event("scene_motion_started", values: ["usesCamera": usesCamera ? 1 : 0])
        #if DEBUG
        diagnosticStart = CACurrentMediaTime()
        cameraFrames = 0
        displayTicks = 0
        print("[FaceParallax] Starting scene motion; camera enabled=\(usesCamera).")
        #endif
        projection.reset()
        inertialViewer = InertialViewer()
        target = nil
        targetEye = nil
        eyePosition = neutralReference
        acquisition = SceneAcquisitionEasing()
        sceneActivation = 0
        referenceEye = nil
        lastFaceTime = 0
        lastDisplayTime = 0
        smoother.reset(to: fallback)
        attitude = fallback
        cameraCadence.reset()
        let configuration = ARFaceTrackingConfiguration()
        if let format = ARFaceTrackingConfiguration.supportedVideoFormats.first(where: { $0.framesPerSecond == 30 }) {
            configuration.videoFormat = format
        }
        PerformanceDiagnostics.shared.event("camera_cadence", values: [
            "captureFPS": Double(configuration.videoFormat.framesPerSecond), "poseFPS": 30, "displayTargetHz": Double(CardDisplayFrameRate.range(
                lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                maximumRefreshHz: Float(UIScreen.main.maximumFramesPerSecond)).preferred ?? 60)
        ])
        configuration.maximumNumberOfTrackedFaces = 1
        configuration.isLightEstimationEnabled = false
        configuration.providesAudioData = false
        if usesCamera && ARFaceTrackingConfiguration.isSupported &&
            AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            // Face perspective needs video only. Keep music and podcasts from
            // other apps playing if ARKit activates the application audio session.
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            } catch {
                // Audio configuration must not prevent the camera/gyro scene.
                PerformanceDiagnostics.shared.event("camera_audio_configuration_failed")
            }
            session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
        let generation = orientations.reset()
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 60
            motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: gyroQueue,
                                            withHandler: orientations.motionHandler(generation: generation))
        }
        let receiver = DisplayLinkTarget(owner: self)
        linkTarget = receiver
        let link = CADisplayLink(target: receiver, selector: #selector(DisplayLinkTarget.tick(_:)))
        link.preferredFrameRateRange = CardDisplayFrameRate.range(lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            maximumRefreshHz: Float(UIScreen.main.maximumFramesPerSecond))
        link.add(to: .main, forMode: .common)
        displayLink = link
        status = "Finding your face"
    }

    @objc nonisolated private func powerStateChanged() {
        Task { @MainActor [weak self] in self?.updateDisplayFrameRate() }
    }

    private func updateDisplayFrameRate() {
        guard let displayLink else { return }
        displayLink.preferredFrameRateRange = CardDisplayFrameRate.range(
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            maximumRefreshHz: Float(UIScreen.main.maximumFramesPerSecond))
        PerformanceDiagnostics.shared.event("scene_display_cadence", values: [
            "minimumHz": Double(displayLink.preferredFrameRateRange.minimum),
            "preferredHz": Double(displayLink.preferredFrameRateRange.preferred ?? 0)
        ])
    }

    private func stop() {
        #if DEBUG
        if displayLink != nil { print("[FaceParallax] Tracking stopped; camera session paused.") }
        #endif
        session.pause()
        session.delegate = nil
        // Release ARKit's retained frame/anchors when the feature stops.
        session = ARSession()
        session.delegate = self
        session.delegateQueue = DispatchQueue(label: "FaceParallax.camera", qos: .userInteractive)
        motion.stopDeviceMotionUpdates()
        orientations.reset()
        inertialViewer = InertialViewer()
        displayLink?.invalidate()
        displayLink = nil
        linkTarget = nil
        target = nil
        targetEye = nil
        eyePosition = nil
        referenceEye = nil
        acquisition = SceneAcquisitionEasing()
        sceneActivation = 0
        projection.reset()
        attitude = fallback
        status = enabled ? "Face parallax paused" : "Face parallax off"
    }

    nonisolated public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let timestamp = frame.timestamp
        guard cameraCadence.accepts(timestamp) else { return }
        var position: ViewerPosition?
        if let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first, face.isTracked {
            let left = face.leftEyeTransform.columns.3
            let right = face.rightEyeTransform.columns.3
            let midpoint = SIMD4<Float>((left.x + right.x) / 2, (left.y + right.y) / 2,
                                        (left.z + right.z) / 2, 1)
            let eye = frame.camera.viewMatrix(for: .portrait) * face.transform * midpoint
            position = ViewerPosition(x: Double(eye.x), y: Double(eye.y), distance: Double(-eye.z))
        }
        let measured = position
        Task { @MainActor [weak self] in
            self?.receive(position: measured, timestamp: timestamp)
        }
    }

    private func receive(position: ViewerPosition?, timestamp: Double) {
        let age = abs(CACurrentMediaTime() - timestamp)
        PerformanceDiagnostics.shared.receivedCamera(valid: position != nil && age < 0.15,
                                                     ageSeconds: age)
        #if DEBUG
        cameraFrames += 1
        #endif
        guard active, enabled, usesCamera, displayLink != nil else { return }
        // Do not replay old camera corrections if UI work delayed delivery.
        guard abs(CACurrentMediaTime() - timestamp) < 0.15 else { return }
        guard let position else {
            recordTrackingInput("ARKit face anchor unavailable or untracked")
            return
        }
        guard let value = projection.attitude(for: position) else {
            recordTrackingInput("pose rejected by distance/finite-value guard")
            return
        }
        recordTrackingInput("valid face pose")
        if referenceEye == nil { referenceEye = neutralReference }
        targetEye = position
        // ARFrame and Core Motion use seconds since boot. Pair the camera pose
        // with its nearest orientation, rather than a delayed delivery time.
        if let sample = orientations.nearest(to: timestamp),
           abs(sample.time - timestamp) < 0.05 {
            inertialViewer.calibrate(eye: position, orientation: sample.value)
        }
        target = value
        lastFaceTime = CACurrentMediaTime()
    }

    nonisolated public func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            PerformanceDiagnostics.shared.event("camera_session_failed")
            self?.stop()
            self?.status = "Face tracking stopped; using gyro"
            PerformanceDiagnostics.shared.setTrackingState("Face tracking stopped; using gyro")
        }
    }

    nonisolated public func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor [weak self] in
            PerformanceDiagnostics.shared.event("camera_session_interrupted")
            self?.target = nil
            self?.lastFaceTime = 0
            self?.status = "Face tracking interrupted; holding scene"
            PerformanceDiagnostics.shared.setTrackingState("Face tracking interrupted; holding scene")
        }
    }

    nonisolated public func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor [weak self] in
            PerformanceDiagnostics.shared.event("camera_session_interruption_ended")
            self?.stop()
            self?.start()
        }
    }

    fileprivate func tick(_ link: CADisplayLink) {
        PerformanceDiagnostics.shared.receivedSceneTick()
        let now = CACurrentMediaTime()
        let tracked = lastFaceTime > 0 && now - lastFaceTime < 0.3
        let delivery = orientations.takeLatest()
        PerformanceDiagnostics.shared.receivedSceneGyro(ageSeconds: delivery.maximumAge, count: delivery.count,
                                                        renderAgeSeconds: delivery.latest.map { now - $0.time })
        let estimate: ViewerPosition?
        // Carry the last measured pose forward on every display tick, including
        // between valid camera frames. Tracking status no longer gates motion.
        if let sample = delivery.latest, abs(now - sample.time) < 0.15 {
            inertialViewer.seedIfNeeded(eye: neutralReference, orientation: sample.value)
            estimate = inertialViewer.estimate(orientation: sample.value)
        } else { estimate = nil }
        let failure = estimate != nil ? nil : delivery.latest == nil ? "no gyro sample" :
            abs(now - (delivery.latest?.time ?? now)) >= 0.15 ? "stale gyro sample" : "invalid projected viewpoint"
        if failure != fallbackFailure {
            fallbackFailure = failure
            PerformanceDiagnostics.shared.event("gyro_fallback: " + (failure ?? "available"))
        }
        let nextEye = estimate ?? (tracked ? targetEye : nil)
        let predictedAttitude = estimate.flatMap { projection.attitude(for: $0) }
        let next = predictedAttitude ?? (tracked ? (target ?? fallback) : (targetEye == nil ? fallback : attitude))
        let nextStatus = !usesCamera ? "Gyro only; camera off" : tracked ? "Face parallax on" :
            (estimate != nil ? "Gyro estimate; face out of view" :
             (targetEye == nil ? "Finding your face" : "Tracking lost; holding scene"))
        if status != nextStatus { status = nextStatus }
        PerformanceDiagnostics.shared.setTrackingState(nextStatus)
        let elapsed = lastDisplayTime > 0 ? link.timestamp - lastDisplayTime : 1.0 / 60
        lastDisplayTime = link.timestamp
        sceneActivation = acquisition.step(hasPose: nextEye != nil || targetEye != nil, elapsed: elapsed)
        attitude = smoother.step(toward: next, elapsed: elapsed)
        if let targetEye = nextEye {
            let previous = eyePosition ?? referenceEye ?? targetEye
            let acquisitionSmoothing = 0.12 * (1 - sceneActivation)
            let alpha = 1 - exp(-max(0, min(elapsed, 0.1)) / max(0.01, smoothingSeconds, acquisitionSmoothing))
            eyePosition = ViewerPosition(
                x: previous.x + alpha * (targetEye.x - previous.x),
                y: previous.y + alpha * (targetEye.y - previous.y),
                distance: previous.distance + alpha * (targetEye.distance - previous.distance)
            )
        }
        #if DEBUG
        displayTicks += 1
        let interval = now - diagnosticStart
        if interval >= 2 {
            print("[FaceParallax] camera updates/s=\(Int(Double(cameraFrames) / interval)), display ticks/s=\(Int(Double(displayTicks) / interval)), face tracked=\(tracked)")
            cameraFrames = 0
            displayTicks = 0
            diagnosticStart = now
        }
        #endif
    }

    private func recordTrackingInput(_ state: String) {
        guard state != trackingInputState else { return }
        PerformanceDiagnostics.shared.event("camera_input: " + state)
        trackingInputState = state
        #if DEBUG
        print("[FaceParallax] Input: \(state)")
        #endif
    }
}

@MainActor private final class DisplayLinkTarget: NSObject {
    weak var owner: FaceParallaxController?
    init(owner: FaceParallaxController) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) { owner?.tick(link) }
}
#endif
