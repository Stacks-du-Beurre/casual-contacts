import Foundation
#if canImport(Darwin)
import Darwin
#endif

public enum DiagnosticViewBody: String, CaseIterable, Sendable {
    case sceneHost, list, card, cardText, backdrop, materialSample, hologram, blendStack
}

/// Aggregate only; no row identities, text, geometry or camera data.
struct RenderingWorkBucket {
    private var bodies: [DiagnosticViewBody: Int] = [:]
    private var sceneWorkCount = 0
    private var sceneWorkMS = 0.0
    private var maximumSceneWorkMS = 0.0

    mutating func receivedBody(_ body: DiagnosticViewBody) { bodies[body, default: 0] += 1 }

    mutating func receivedSceneWork(seconds: Double) {
        guard seconds.isFinite, seconds >= 0 else { return }
        sceneWorkCount += 1
        let ms = seconds * 1000
        sceneWorkMS += ms
        maximumSceneWorkMS = max(maximumSceneWorkMS, ms)
    }

    var values: [String: Double] {
        var result = Dictionary(uniqueKeysWithValues: DiagnosticViewBody.allCases.map {
            ("viewBody_" + $0.rawValue, Double(bodies[$0, default: 0]))
        })
        result["sceneWorkCount"] = Double(sceneWorkCount)
        result["sceneWorkTotalMS"] = sceneWorkMS
        result["sceneWorkMaximumMS"] = maximumSceneWorkMS
        return result
    }
}

struct DiagnosticCPUReading {
    let processSeconds: Double
    let mainThreadSeconds: Double

    /// Call from the main actor: the thread clock measures the calling thread.
    @MainActor static func capture() -> Self? {
        #if canImport(Darwin)
        var process = timespec(), thread = timespec()
        guard clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &process) == 0,
              clock_gettime(CLOCK_THREAD_CPUTIME_ID, &thread) == 0 else { return nil }
        return Self(processSeconds: Double(process.tv_sec) + Double(process.tv_nsec) / 1e9,
                    mainThreadSeconds: Double(thread.tv_sec) + Double(thread.tv_nsec) / 1e9)
        #else
        return nil
        #endif
    }

    func values(since previous: Self, elapsed: Double) -> [String: Double] {
        let process = processSeconds - previous.processSeconds
        let main = mainThreadSeconds - previous.mainThreadSeconds
        guard elapsed.isFinite, elapsed > 0,
              process.isFinite, main.isFinite, process >= 0, main >= 0 else { return [:] }
        return ["processCPUMS": process * 1000, "mainThreadCPUMS": main * 1000,
                // 100% is one fully occupied CPU core; process use can exceed it.
                "processCPUCorePercent": process / elapsed * 100,
                "mainThreadCPUCorePercent": main / elapsed * 100]
    }
}
