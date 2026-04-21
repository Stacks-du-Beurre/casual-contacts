import Testing
import Foundation
import CoreModels
@testable import Services

#if canImport(Vision) && !os(macOS)
import Vision

@Suite struct VisionFaceDetectionServiceTests {

    @Test func emptyObservationsYieldNil() {
        #expect(VisionFaceDetectionService.largestFaceCenter(from: []) == nil)
    }

    @Test func singleFaceReturnsBoxCenterInTopLeftCoords() {
        // Vision's bottom-left origin: a box at (0.2, 0.6) with size 0.2×0.2 covers
        // the top portion of the image. The box center in bottom-up coords is
        // (0.3, 0.7); converted to top-left coords that becomes (0.3, 0.3).
        let observation = VNFaceObservation(boundingBox: CGRect(x: 0.2, y: 0.6, width: 0.2, height: 0.2))
        let center = VisionFaceDetectionService.largestFaceCenter(from: [observation])
        #expect(abs((center?.x ?? 0) - 0.3) < 0.0001)
        #expect(abs((center?.y ?? 0) - 0.3) < 0.0001)
    }

    @Test func picksLargestFace() {
        // Small face bottom-left, large face top-right.
        let small = VNFaceObservation(boundingBox: CGRect(x: 0.05, y: 0.05, width: 0.1, height: 0.1))
        let large = VNFaceObservation(boundingBox: CGRect(x: 0.5, y: 0.5, width: 0.4, height: 0.4))
        let center = VisionFaceDetectionService.largestFaceCenter(from: [small, large])
        // Large box center bottom-up: (0.7, 0.7) → top-down y = 0.3.
        #expect(abs((center?.x ?? 0) - 0.7) < 0.0001)
        #expect(abs((center?.y ?? 0) - 0.3) < 0.0001)
    }

    @Test func malformedDataReturnsNil() async {
        let service = VisionFaceDetectionService()
        let result = await service.focusPoint(in: Data())
        #expect(result == nil)
    }
}

#endif
