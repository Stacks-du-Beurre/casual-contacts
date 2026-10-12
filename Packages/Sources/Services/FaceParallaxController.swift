#if os(iOS)
import ARKit
import AVFoundation
import CoreModels
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
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var linkTarget: DisplayLinkTarget?
    @ObservationIgnored private var projection = ViewerParallax()
    @ObservationIgnored private var smoother = DisplayAttitudeSmoother()
    @ObservationIgnored private var target: DeviceAttitude?
    @ObservationIgnored private var targetEye: ViewerPosition?
    @ObservationIgnored private var lastFaceTime: TimeInterval = 0
    @ObservationIgnored private var lastDisplayTime: TimeInterval = 0
    @ObservationIgnored private var active = false
    @ObservationIgnored private var requestID = 0
    #if DEBUG
    @ObservationIgnored private var diagnosticStart: TimeInterval = 0
    @ObservationIgnored private var cameraFrames = 0
    @ObservationIgnored private var displayTicks = 0
    #endif

    public override init() {
        super.init()
        session.delegate = self
        session.delegateQueue = .main
    }

    public func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        if enabled { start() } else { stop() }
    }

    public func setActive(_ active: Bool) {
        self.active = active
        if active && enabled { start() } else { stop() }
    }

    public func recenter() {
        projection.reset()
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

    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        #if DEBUG
        cameraFrames += 1
        #endif
        guard active, enabled, displayLink != nil,
              let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first,
              face.isTracked else { return }
        let left = face.leftEyeTransform.columns.3
        let right = face.rightEyeTransform.columns.3
        let midpoint = SIMD4<Float>((left.x + right.x) / 2, (left.y + right.y) / 2,
                                    (left.z + right.z) / 2, 1)
        // The app is portrait-only on iPhone. viewMatrix rotates ARKit's native
        // camera axes into the screen's right/up convention, without mirroring.
        let eye = frame.camera.viewMatrix(for: .portrait) * face.transform * midpoint
        let position = ViewerPosition(x: Double(eye.x), y: Double(eye.y), distance: Double(-eye.z))
        guard let value = projection.attitude(for: position) else { return }
        if referenceEye == nil { referenceEye = position }
        targetEye = position
        target = value
        lastFaceTime = CACurrentMediaTime()
    }

    public func session(_ session: ARSession, didFailWithError error: Error) {
        stop()
        status = "Face tracking stopped; using gyro"
        #if DEBUG
        print("[FaceParallax] AR session failed; using gyro fallback.")
        #endif
    }

    public func sessionWasInterrupted(_ session: ARSession) {
        target = nil
        status = "Face tracking interrupted; using gyro"
    }

    public func sessionInterruptionEnded(_ session: ARSession) {
        stop()
        start()
    }

    fileprivate func tick(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        let tracked = lastFaceTime > 0 && now - lastFaceTime < 0.3
        let next = tracked ? (target ?? fallback) : fallback
        let nextStatus = tracked ? "Face parallax on" : "Finding your face; using gyro"
        if status != nextStatus { status = nextStatus }
        let elapsed = lastDisplayTime > 0 ? link.timestamp - lastDisplayTime : 1.0 / 60
        lastDisplayTime = link.timestamp
        attitude = smoother.step(toward: next, elapsed: elapsed)
        if tracked, let targetEye {
            let previous = eyePosition ?? referenceEye ?? targetEye
            let alpha = 1 - exp(-max(0, min(elapsed, 0.1)) / max(0.01, smoothingSeconds))
            eyePosition = ViewerPosition(
                x: previous.x + alpha * (targetEye.x - previous.x),
                y: previous.y + alpha * (targetEye.y - previous.y),
                distance: previous.distance + alpha * (targetEye.distance - previous.distance)
            )
        } else {
            eyePosition = nil
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
}

@MainActor private final class DisplayLinkTarget: NSObject {
    weak var owner: FaceParallaxController?
    init(owner: FaceParallaxController) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) { owner?.tick(link) }
}
#endif
