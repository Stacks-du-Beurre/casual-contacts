#if os(iOS)
import ARKit
import AVFoundation
import CoreModels
import CoreMotion
import Observation
import UIKit

/// Owns the camera only while the full-screen card opts in and is active.
@MainActor @Observable
public final class FaceParallaxController: NSObject, @preconcurrency ARSessionDelegate {
    public private(set) var attitude: DeviceAttitude = .zero
    public private(set) var status = "Face parallax off"
    public private(set) var enabled = false
    public var fallback: DeviceAttitude = .zero
    public var smoothingSeconds: Double = 0.035
    public private(set) var eyePosition: ViewerPosition?
    public private(set) var referenceEye: ViewerPosition?
    public var renderingAttitude: DeviceAttitude { displayLink == nil ? fallback : attitude }

    @ObservationIgnored private let session = ARSession()
    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var inertialViewer = InertialViewer()
    @ObservationIgnored private var orientations: [(time: Double, value: Quaternion)] = []
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
    @ObservationIgnored private var requestID = 0
    @ObservationIgnored private var trackingInputState = "waiting"
    #if DEBUG
    @ObservationIgnored private var diagnosticStart: TimeInterval = 0
    @ObservationIgnored private var cameraFrames = 0
    @ObservationIgnored private var displayTicks = 0
    #endif

    public override init() {
        super.init()
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
        guard ARFaceTrackingConfiguration.isSupported else {
            status = "Face tracking unavailable; using gyro"
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: runSession()
        case .notDetermined:
            requestID += 1
            let id = requestID
            status = "Waiting for camera permission"
            Task { [weak self] in
                let allowed = await AVCaptureDevice.requestAccess(for: .video)
                guard let self, self.requestID == id, self.active, self.enabled else { return }
                if allowed { self.runSession() }
                else { self.status = "Camera access denied; using gyro" }
            }
        default: status = "Camera access denied; using gyro"
        }
    }

    private func runSession() {
        #if DEBUG
        diagnosticStart = CACurrentMediaTime()
        cameraFrames = 0
        displayTicks = 0
        print("[FaceParallax] Starting front-camera tracking; frames are not stored.")
        #endif
        projection.reset()
        inertialViewer = InertialViewer()
        target = nil
        targetEye = nil
        eyePosition = nil
        referenceEye = nil
        lastFaceTime = 0
        lastDisplayTime = 0
        smoother.reset(to: fallback)
        attitude = fallback
        let configuration = ARFaceTrackingConfiguration()
        configuration.maximumNumberOfTrackedFaces = 1
        configuration.isLightEstimationEnabled = false
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        orientations.removeAll()
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 60
            motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] sample, _ in
                MainActor.assumeIsolated {
                    guard let self, let sample, self.active, self.enabled else { return }
                    let q = sample.attitude.quaternion
                    self.orientations.append((sample.timestamp, Quaternion(x: q.x, y: q.y, z: q.z, w: q.w)))
                    if self.orientations.count > 120 { self.orientations.removeFirst() }
                }
            }
        }
        let receiver = DisplayLinkTarget(owner: self)
        linkTarget = receiver
        let link = CADisplayLink(target: receiver, selector: #selector(DisplayLinkTarget.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
        status = "Finding your face"
    }

    private func stop() {
        #if DEBUG
        if displayLink != nil { print("[FaceParallax] Tracking stopped; camera session paused.") }
        #endif
        requestID += 1
        session.pause()
        motion.stopDeviceMotionUpdates()
        orientations.removeAll()
        inertialViewer = InertialViewer()
        displayLink?.invalidate()
        displayLink = nil
        linkTarget = nil
        target = nil
        targetEye = nil
        eyePosition = nil
        referenceEye = nil
        projection.reset()
        attitude = fallback
        status = enabled ? "Face parallax paused" : "Face parallax off"
    }

    nonisolated public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let timestamp = frame.timestamp
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
        #if DEBUG
        cameraFrames += 1
        #endif
        guard active, enabled, displayLink != nil else { return }
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
        if let sample = orientations.min(by: { abs($0.time - timestamp) < abs($1.time - timestamp) }),
           abs(sample.time - timestamp) < 0.05 {
            inertialViewer.calibrate(eye: position, orientation: sample.value)
        }
        target = value
        lastFaceTime = CACurrentMediaTime()
    }

    nonisolated public func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.stop()
            self?.status = "Face tracking stopped; using gyro"
        }
    }

    nonisolated public func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor [weak self] in
            self?.target = nil
            self?.lastFaceTime = 0
            self?.status = "Face tracking interrupted; holding scene"
        }
    }

    nonisolated public func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor [weak self] in
            self?.stop()
            self?.start()
        }
    }

    fileprivate func tick(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        let tracked = lastFaceTime > 0 && now - lastFaceTime < 0.3
        let estimate: ViewerPosition?
        // Carry the last measured pose forward on every display tick, including
        // between valid camera frames. Tracking status no longer gates motion.
        if let sample = orientations.last, abs(now - sample.time) < 0.15 {
            estimate = inertialViewer.estimate(orientation: sample.value)
        } else { estimate = nil }
        let nextEye = estimate ?? (tracked ? targetEye : nil)
        let predictedAttitude = estimate.flatMap { projection.attitude(for: $0) }
        let next = predictedAttitude ?? (tracked ? (target ?? fallback) : (eyePosition == nil ? fallback : attitude))
        let nextStatus = tracked ? "Face parallax on" :
            (estimate != nil ? "Gyro estimate; face out of view" :
             (eyePosition == nil ? "Finding your face; using gyro" : "Tracking lost; holding scene"))
        if status != nextStatus { status = nextStatus }
        let elapsed = lastDisplayTime > 0 ? link.timestamp - lastDisplayTime : 1.0 / 60
        lastDisplayTime = link.timestamp
        attitude = smoother.step(toward: next, elapsed: elapsed)
        if let targetEye = nextEye {
            let previous = eyePosition ?? referenceEye ?? targetEye
            let alpha = 1 - exp(-max(0, min(elapsed, 0.1)) / max(0.01, smoothingSeconds))
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
