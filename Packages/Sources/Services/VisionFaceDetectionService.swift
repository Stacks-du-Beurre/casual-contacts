import Foundation
import CoreModels
#if canImport(Vision) && !os(macOS)
import Vision
#if canImport(UIKit)
import UIKit
#endif
#endif

public final class VisionFaceDetectionService: FaceDetectionService, @unchecked Sendable {

    public init() {}

    #if canImport(Vision) && !os(macOS)

    public func focusPoint(in imageData: Data) async -> CoreModels.NormalizedPoint? {
        // Vision's completion handler can fire even when `perform` throws,
        // so guard against double-resume — the continuation is resumed by
        // whichever path runs first.
        await withCheckedContinuation { continuation in
            let resumeBox = ResumeOnce()
            let request = VNDetectFaceRectanglesRequest { request, _ in
                let observations = (request.results as? [VNFaceObservation]) ?? []
                let point = Self.largestFaceCenter(from: observations)
                resumeBox.resumeOnce { continuation.resume(returning: point) }
            }
            let handler = VNImageRequestHandler(data: imageData, orientation: Self.orientation(for: imageData))
            do {
                try handler.perform([request])
            } catch {
                resumeBox.resumeOnce { continuation.resume(returning: nil) }
            }
        }
    }

    /// One-shot gate that ensures the continuation is resumed at most once,
    /// even when Vision calls both the completion handler and throws from
    /// `perform` for the same request.
    private final class ResumeOnce: @unchecked Sendable {
        private let lock = NSLock()
        private var fired = false
        func resumeOnce(_ action: () -> Void) {
            lock.lock()
            let shouldFire = !fired
            fired = true
            lock.unlock()
            if shouldFire { action() }
        }
    }

    /// Vision returns `boundingBox` in normalized coordinates with origin at the
    /// bottom-left. Convert to top-left origin and return the box's center.
    static func largestFaceCenter(from observations: [VNFaceObservation]) -> CoreModels.NormalizedPoint? {
        guard let largest = observations.max(by: { a, b in
            (a.boundingBox.width * a.boundingBox.height) < (b.boundingBox.width * b.boundingBox.height)
        }) else { return nil }

        let box = largest.boundingBox
        let centerX = box.origin.x + box.width / 2
        let centerYBottomUp = box.origin.y + box.height / 2
        let centerYTopDown = 1 - centerYBottomUp
        return CoreModels.NormalizedPoint(x: centerX, y: centerYTopDown)
    }

    /// UIImage's embedded orientation drives how Vision interprets the pixel
    /// buffer. Without this, portrait photos get analyzed as if they were
    /// landscape and face centers land in the wrong quadrant.
    private static func orientation(for data: Data) -> CGImagePropertyOrientation {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return .up }
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
        #else
        return .up
        #endif
    }

    #else

    public func focusPoint(in imageData: Data) async -> CoreModels.NormalizedPoint? {
        nil
    }

    #endif
}
