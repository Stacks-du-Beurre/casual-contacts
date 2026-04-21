import Foundation

/// Locates the primary face in a photo so the render pipeline can center on it.
///
/// Implementations are expected to be tolerant: malformed input, missing faces,
/// or framework-level errors should resolve to `nil` (the caller interprets nil
/// as "render centered"). This protocol never throws.
public protocol FaceDetectionService: Sendable {
    /// Returns the normalized center (origin top-left, both axes ∈ [0, 1]) of
    /// the largest detected face in `imageData`, or `nil` if no face is
    /// detected or detection fails.
    func focusPoint(in imageData: Data) async -> NormalizedPoint?
}
