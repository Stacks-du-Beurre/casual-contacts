import Foundation

/// Callback timing describes main-thread availability, not GPU-presented FPS.
public struct CallbackTimingSummary: Codable, Sendable {
    public let count: Int
    public let medianMS: Double
    public let p95MS: Double
    public let maximumMS: Double
    public let over33MS: Int
    public let over100MS: Int

    public init(intervalsMS: [Double]) {
        let values = intervalsMS.filter { $0.isFinite && $0 >= 0 }.sorted()
        count = values.count
        let middle = values.count / 2
        medianMS = values.isEmpty ? 0 : (values.count.isMultiple(of: 2)
            ? (values[middle - 1] + values[middle]) / 2 : values[middle])
        p95MS = values.isEmpty ? 0 : values[Int(Double(values.count - 1) * 0.95)]
        maximumMS = values.last ?? 0
        over33MS = values.filter { $0 > 33.34 }.count
        over100MS = values.filter { $0 > 100 }.count
    }
}

#if os(iOS)
import UIKit
import Observation

/// Opt-in, bounded diagnostics. No per-frame disk writes or personal content.
@MainActor @Observable public final class PerformanceDiagnostics: NSObject {
    public static let shared = PerformanceDiagnostics()
    public private(set) var isRecording = false
    public private(set) var hasRecording = false
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var started = 0.0
    @ObservationIgnored private var bucketStart = 0.0
    @ObservationIgnored private var previous = 0.0
    @ObservationIgnored private var intervals: [Double] = []
    @ObservationIgnored private var expectedIntervalMS = 0.0
    @ObservationIgnored private var gyroUpdates = 0
    @ObservationIgnored private var cameraFrames = 0
    @ObservationIgnored private var validCameraFrames = 0
    @ObservationIgnored private var staleCameraFrames = 0
    @ObservationIgnored private var maximumCameraAgeMS = 0.0
    @ObservationIgnored private var sceneTicks = 0
    @ObservationIgnored private var sceneDisplayCallbacks = 0
    @ObservationIgnored private var sceneGyroSamples = 0
    @ObservationIgnored private var maximumGyroAgeMS = 0.0
    @ObservationIgnored private var maximumGyroRenderAgeMS = 0.0
    @ObservationIgnored private var context = "list"
    @ObservationIgnored private var trackingState = "unknown"
    @ObservationIgnored private var transitionStart = 0.0
    @ObservationIgnored private var transitionIntervals: [Double] = []
    @ObservationIgnored private var transitionName: String?
    @ObservationIgnored private var foregroundStarted = 0.0
    @ObservationIgnored private var awaitingGyro = false
    @ObservationIgnored private var awaitingCamera = false
    @ObservationIgnored private var awaitingScene = false
    @ObservationIgnored private var rows: [Row] = []
    @ObservationIgnored private var metadata: [String: String] = [:]

    @ObservationIgnored private var transitionCameraFrames = 0
    @ObservationIgnored private var transitionMaximumCameraAgeMS = 0.0
    @ObservationIgnored private var transitionMinimumScheduledMS = Double.infinity
    @ObservationIgnored private var transitionMaximumScheduledMS = 0.0

    public override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(powerStateChanged),
                                               name: .NSProcessInfoPowerStateDidChange, object: nil)
    }

    @objc nonisolated private func powerStateChanged() {
        Task { @MainActor [weak self] in self?.updateDisplayFrameRate() }
    }

    private func updateDisplayFrameRate() {
        guard let link else { return }
        link.preferredFrameRateRange = CardDisplayFrameRate.range(
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            maximumRefreshHz: Float(UIScreen.main.maximumFramesPerSecond))
        event("diagnostic_display_cadence", values: [
            "minimumHz": Double(link.preferredFrameRateRange.minimum),
            "preferredHz": Double(link.preferredFrameRateRange.preferred ?? 0)
        ])
    }

    private struct Row: Codable, Sendable {
        let seconds: Double
        let event: String
        let context: String
        let tracking: String
        var values: [String: Double] = [:]
        var timing: CallbackTimingSummary?
    }
    private struct Report: Codable, Sendable {
        let schemaVersion = 1
        let note = "Display callbacks measure main-thread cadence, not GPU-presented FPS. Times are seconds since recording began. No images, positions, contacts, or identifiers are recorded."
        let metadata: [String: String]
        let rows: [Row]
    }

    public func start() {
        stop()
        rows = []
        started = CACurrentMediaTime()
        bucketStart = started
        previous = 0
        resetBucket()
        var system = utsname()
        uname(&system)
        let hardware = withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        metadata = ["hardware": hardware, "os": UIDevice.current.systemVersion,
                    "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                    "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
                    "maximumRefreshHz": String(UIScreen.main.maximumFramesPerSecond),
                    "startedUTC": ISO8601DateFormatter().string(from: Date())]
        #if targetEnvironment(simulator)
        metadata["environment"] = "simulator"
        #else
        metadata["environment"] = "device"
        #endif
        isRecording = true
        foregroundStarted = started
        awaitingGyro = true; awaitingCamera = true; awaitingScene = true
        hasRecording = true
        event("recording_started")
        let displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        // Match scene pacing so recording does not request a different refresh rate.
        displayLink.preferredFrameRateRange = CardDisplayFrameRate.range(lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            maximumRefreshHz: Float(UIScreen.main.maximumFramesPerSecond))
        displayLink.add(to: .main, forMode: .common)
        link = displayLink
    }

    public func stop() {
        guard isRecording else { return }
        flush()
        event("recording_stopped")
        isRecording = false
        link?.invalidate()
        link = nil
        transitionName = nil
        transitionIntervals = []
    }

    public func event(_ name: String, values: [String: Double] = [:]) {
        guard isRecording else { return }
        append(Row(seconds: CACurrentMediaTime() - started, event: name,
                   context: context, tracking: trackingState, values: values))
    }

    public func setForeground(_ active: Bool) {
        guard isRecording else { return }
        flush()
        event(active ? "foreground" : "inactive")
        if active {
            foregroundStarted = CACurrentMediaTime()
            awaitingGyro = true; awaitingCamera = true; awaitingScene = true
        }
        previous = 0 // Background time is not a rendering stall.
        bucketStart = CACurrentMediaTime()
        link?.isPaused = !active
    }

    public func setContext(_ value: String) { context = value; event("context_changed") }
    public func setTrackingState(_ value: String) {
        guard value != trackingState else { return }
        trackingState = value
        event("tracking_changed")
    }
    public func receivedGyro() {
        guard isRecording else { return }
        gyroUpdates += 1
        if awaitingGyro { awaitingGyro = false; recordFirstUpdate("first_gyro_pose_change") }
    }
    public func receivedSceneDisplayCallback() {
        guard isRecording else { return }
        sceneDisplayCallbacks += 1
    }
    public func receivedSceneTick() {
        guard isRecording else { return }
        sceneTicks += 1
        if awaitingScene { awaitingScene = false; recordFirstUpdate("first_scene_tick") }
    }
    public func receivedSceneGyro(ageSeconds: Double, count: Int = 1, renderAgeSeconds: Double? = nil) {
        guard isRecording else { return }
        sceneGyroSamples += count
        maximumGyroAgeMS = max(maximumGyroAgeMS, abs(ageSeconds) * 1000)
        if let renderAgeSeconds { maximumGyroRenderAgeMS = max(maximumGyroRenderAgeMS, abs(renderAgeSeconds) * 1000) }
    }
    public func receivedCamera(valid: Bool, ageSeconds: Double) {
        guard isRecording else { return }
        cameraFrames += 1
        if valid { validCameraFrames += 1 }
        if valid && awaitingCamera { awaitingCamera = false; recordFirstUpdate("first_valid_camera_delivery") }
        if ageSeconds >= 0.15 { staleCameraFrames += 1 }
        maximumCameraAgeMS = max(maximumCameraAgeMS, abs(ageSeconds) * 1000)
        if transitionName != nil {
            transitionCameraFrames += 1
            transitionMaximumCameraAgeMS = max(transitionMaximumCameraAgeMS, abs(ageSeconds) * 1000)
        }
    }

    public func beginTransition(_ name: String, hasPhoto: Bool) {
        guard isRecording else { return }
        transitionName = name
        transitionStart = CACurrentMediaTime()
        transitionCameraFrames = 0
        transitionMaximumCameraAgeMS = 0
        transitionMinimumScheduledMS = .infinity
        transitionMaximumScheduledMS = 0
        transitionIntervals = []
        event(name + "_started", values: ["hasPhoto": hasPhoto ? 1 : 0])
    }
    public func endTransition(_ name: String) {
        guard isRecording, transitionName == name else { return }
        append(Row(seconds: CACurrentMediaTime() - started, event: name + "_completed",
                   context: context, tracking: trackingState,
                   values: ["durationMS": (CACurrentMediaTime() - transitionStart) * 1000,
                            "cameraFrames": Double(transitionCameraFrames),
                            "maximumCameraAgeMS": transitionMaximumCameraAgeMS,
                            "minimumScheduledIntervalMS": transitionMinimumScheduledMS.isFinite ? transitionMinimumScheduledMS : 0,
                            "maximumScheduledIntervalMS": transitionMaximumScheduledMS],
                   timing: CallbackTimingSummary(intervalsMS: transitionIntervals)))
        transitionName = nil
        transitionIntervals = []
    }

    @objc private func tick(_ displayLink: CADisplayLink) {
        let now = CACurrentMediaTime()
        expectedIntervalMS = (displayLink.targetTimestamp - displayLink.timestamp) * 1000
        if transitionName != nil {
            transitionMinimumScheduledMS = min(transitionMinimumScheduledMS, expectedIntervalMS)
            transitionMaximumScheduledMS = max(transitionMaximumScheduledMS, expectedIntervalMS)
        }
        if previous > 0 {
            let interval = (now - previous) * 1000
            intervals.append(interval)
            if transitionName != nil, transitionIntervals.count < 1200 { transitionIntervals.append(interval) }
        }
        previous = now
        if now - bucketStart >= 1 { flush(); bucketStart = now }
        if now - started >= 600 { stop() }
    }

    private func flush() {
        guard isRecording else { return }
        let elapsed = CACurrentMediaTime() - bucketStart
        guard elapsed > 0 else { return }
        append(Row(seconds: CACurrentMediaTime() - started, event: "sample",
                   context: context, tracking: trackingState,
                   values: ["windowSeconds": elapsed, "gyroUpdates": Double(gyroUpdates),
                            "expectedCallbackIntervalMS": expectedIntervalMS,
                            "cameraFrames": Double(cameraFrames), "validCameraFrames": Double(validCameraFrames),
                            "staleCameraFrames": Double(staleCameraFrames), "maximumCameraAgeMS": maximumCameraAgeMS,
                            "sceneDisplayCallbacks": Double(sceneDisplayCallbacks),
                            "sceneTicks": Double(sceneTicks), "thermalState": Double(ProcessInfo.processInfo.thermalState.rawValue),
                            "sceneGyroSamples": Double(sceneGyroSamples), "maximumGyroAgeMS": maximumGyroAgeMS,
                            "maximumGyroRenderAgeMS": maximumGyroRenderAgeMS,
                            "residentMemoryMB": residentMemoryMB(),
                            "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled ? 1 : 0],
                   timing: CallbackTimingSummary(intervalsMS: intervals)))
        resetBucket()
    }
    private func resetBucket() {
        intervals = []
        gyroUpdates = 0; cameraFrames = 0; validCameraFrames = 0; staleCameraFrames = 0
        maximumCameraAgeMS = 0; sceneTicks = 0; sceneDisplayCallbacks = 0
        sceneGyroSamples = 0; maximumGyroAgeMS = 0
        maximumGyroRenderAgeMS = 0
    }
    private func recordFirstUpdate(_ name: String) {
        event(name, values: ["sinceForegroundMS": (CACurrentMediaTime() - foregroundStarted) * 1000])
    }
    private func residentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : -1
    }
    private func append(_ row: Row) {
        // Hard memory bound, even if tracking state changes frequently.
        if rows.count >= 3000 { rows.removeFirst(500) }
        rows.append(row)
    }

    public func export() async throws -> URL {
        stop()
        let report = Report(metadata: metadata, rows: rows)
        return try await Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("casual-contacts-performance.json")
            try encoder.encode(report).write(to: url, options: .atomic)
            return url
        }.value
    }
}
#endif
