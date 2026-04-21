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
            // Landmarks request is a superset of the rectangles request — it
            // returns the same face bounding boxes PLUS per-face landmarks.
            // Centering on the landmarks bbox (eyes/nose/mouth/contour) gives
            // an anatomically accurate face center; the bare rectangles bbox
            // drifts because it includes hair and ear overhang.
            let request = VNDetectFaceLandmarksRequest { request, _ in
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

    /// Returns the center of the largest face in image-normalized, top-left
    /// coordinates. Prefers the bounding box of the face landmarks (eyes,
    /// nose, mouth, contour) when available; falls back to the observation's
    /// overall bounding box otherwise.
    static func largestFaceCenter(from observations: [VNFaceObservation]) -> CoreModels.NormalizedPoint? {
        guard let largest = observations.max(by: { a, b in
            (a.boundingBox.width * a.boundingBox.height) < (b.boundingBox.width * b.boundingBox.height)
        }) else { return nil }

        let bottomUpCenter = landmarksCenter(for: largest) ?? boundingBoxCenter(of: largest.boundingBox)
        // Flip Y from Vision's bottom-left origin to top-left.
        return CoreModels.NormalizedPoint(x: bottomUpCenter.x, y: 1 - bottomUpCenter.y)
    }

    private static func boundingBoxCenter(of box: CGRect) -> CGPoint {
        CGPoint(x: box.origin.x + box.width / 2, y: box.origin.y + box.height / 2)
    }

    /// Computes the bounding-box center of all available facial landmarks in
    /// image-normalized (bottom-up) coordinates. Landmark points are stored in
    /// coordinates normalized to the observation's bounding box, so we project
    /// them back into image-normalized space before measuring.
    private static func landmarksCenter(for observation: VNFaceObservation) -> CGPoint? {
        guard let all = observation.landmarks?.allPoints else { return nil }
        let box = observation.boundingBox
        let points = all.normalizedPoints
        guard !points.isEmpty else { return nil }

        var minX = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var minY = CGFloat.infinity
        var maxY = -CGFloat.infinity
        for p in points {
            let x = box.origin.x + p.x * box.width
            let y = box.origin.y + p.y * box.height
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
        return CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
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
