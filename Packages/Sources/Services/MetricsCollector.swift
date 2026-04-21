import Foundation
import os

#if canImport(MetricKit) && !os(macOS)
import MetricKit

/// `MXMetricManagerSubscriber` that captures the daily perf rollup and any
/// crash/hang diagnostics MetricKit delivers. Payloads are JSON-serialized,
/// emitted to Unified Logging (visible via Console.app or `log stream`), and
/// persisted to `Documents/MetricKit/` so a debug UI (or a manual file pull
/// over the iTunes-style file sharing path) can review them later.
///
/// MetricKit delivers metrics on a 24-hour cadence — payloads typically arrive
/// at next app launch after the collection window closes. Useful as ongoing
/// telemetry, not real-time validation. For active perf work, drive the app
/// in Instruments instead.
///
/// During development you can synthesize a payload via Xcode's
/// **Debug → Simulate MetricKit Payloads** menu rather than waiting 24 hours.
public final class MetricsCollector: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {

    public static let shared = MetricsCollector()

    private let logger = Logger(subsystem: "com.stacksdubeurre.CasualContacts", category: "metrics")

    /// Idempotent registration. Call from app init.
    public func register() {
        MXMetricManager.shared.add(self)
        logger.info("MetricKit subscriber registered")
    }

    public func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            persist(payload.jsonRepresentation(), kind: "metric", id: payload.timeStampEnd)
        }
    }

    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            persist(payload.jsonRepresentation(), kind: "diagnostic", id: payload.timeStampEnd)
        }
    }

    /// Writes the JSON to `Documents/MetricKit/<kind>-<iso8601>.json` and
    /// emits a single log line so the payload shows up in Console.app right
    /// when MetricKit hands it off.
    private func persist(_ json: Data, kind: String, id endDate: Date) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: endDate)

        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("MetricKit persist failed: no Documents directory")
            return
        }
        let dir = documents.appendingPathComponent("MetricKit", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let url = dir.appendingPathComponent("\(kind)-\(timestamp).json")
        do {
            try json.write(to: url, options: .atomic)
            logger.info("MetricKit \(kind, privacy: .public) payload saved to \(url.lastPathComponent, privacy: .public)")
        } catch {
            logger.error("MetricKit persist failed: \(String(describing: error), privacy: .public)")
        }

        if let preview = String(data: json, encoding: .utf8) {
            logger.info("MetricKit \(kind, privacy: .public) payload: \(preview, privacy: .public)")
        }
    }
}

#else

/// macOS host stub so AppFeature / app target imports compile cross-platform.
public final class MetricsCollector: @unchecked Sendable {
    public static let shared = MetricsCollector()
    public func register() {}
}

#endif
