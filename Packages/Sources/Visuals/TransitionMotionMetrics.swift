#if DEBUG && os(iOS)
import Foundation
import UIKit

/// Debug-only main-thread display callback timings, not GPU-presented frame measurements.
@MainActor public final class TransitionMotionMetrics: NSObject {
    public static let shared = TransitionMotionMetrics()
    public static var isEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-ScreenshotMode"), index + 1 < arguments.count else { return false }
        return arguments[index + 1] == "YES" && arguments.contains("-MotionPerformanceHarness")
    }
    private struct Sample: Codable {
        let phase: String
        let intervalsMS: [Double]
        let motionUpdates: Int
        let durationMS: Double
        let maxDepthMeters: Double
    }
    private var link: CADisplayLink?
    private var phase: String?
    private var intervals: [Double] = []
    private var samples: [Sample] = []
    private var previous = 0.0
    private var began = 0.0
    private var motionUpdates = 0
    private var maxDepthMeters = 0.0

    public func begin(_ phase: String) {
        guard Self.isEnabled else { return }
        self.phase = phase
        intervals = []
        previous = 0
        motionUpdates = 0
        maxDepthMeters = 0
        began = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        self.link?.invalidate()
        self.link = link
    }

    public func receivedMotion(depthMeters: Double) {
        if phase != nil {
            motionUpdates += 1
            maxDepthMeters = max(maxDepthMeters, depthMeters)
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        if previous > 0 { intervals.append((link.timestamp - previous) * 1000) }
        previous = link.timestamp
    }

    public func end() {
        guard let phase else { return }
        samples.append(Sample(phase: phase, intervalsMS: intervals,
                              motionUpdates: motionUpdates,
                              durationMS: (CACurrentMediaTime() - began) * 1000,
                              maxDepthMeters: maxDepthMeters))
        self.phase = nil
        link?.invalidate()
        link = nil
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? JSONEncoder().encode(samples) else { return }
        let filename = ProcessInfo.processInfo.arguments.contains("-MotionScrollHarness")
            ? "scroll-motion-photo-metrics.json" : ProcessInfo.processInfo.arguments.contains("-MotionHarnessPhoto")
            ? "transition-motion-photo-metrics.json" : "transition-motion-metrics.json"
        try? data.write(to: directory.appendingPathComponent(filename), options: .atomic)
    }
}
#endif
