import Testing
import SwiftUI
import CoreModels
@testable import Visuals

@Suite struct PhotoLayerTests {

    @Test @MainActor func cardStyleInstantiates() {
        let layer = PhotoLayer(image: Image(systemName: "photo"), style: .card)
        _ = layer.body
    }

    @Test @MainActor func recommendedStyleInstantiates() {
        let layer = PhotoLayer(image: Image(systemName: "photo"), style: .recommended)
        _ = layer.body
    }

    @Test @MainActor func zeroParallaxPreservesScaledToFillLayout() {
        let layout = PhotoLayer.focusLayout(
            container: CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 200, height: 100),
            focus: .center,
            zoomMultiplier: 1,
            parallaxOffset: .zero
        )

        #expect(layout.scaled == CGSize(width: 200, height: 100))
        #expect(layout.offset == .zero)
    }

    @Test @MainActor func parallaxLayoutReservesEnoughOverflowToMoveWithoutEmptyEdges() {
        let parallaxOffset = CGSize(width: 20, height: -10)
        let layout = PhotoLayer.focusLayout(
            container: CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 100, height: 100),
            focus: .center,
            zoomMultiplier: 1,
            parallaxOffset: parallaxOffset
        )

        #expect(layout.scaled.width >= 100 + 2 * abs(parallaxOffset.width))
        #expect(layout.scaled.height >= 100 + 2 * abs(parallaxOffset.height))
        #expect(layout.offset == parallaxOffset)
    }

    @Test @MainActor func fixedParallaxOverscanKeepsScaleStableAcrossLiveOffsets() {
        let maxParallax = CGSize(width: 30, height: 18)
        let atRest = PhotoLayer.focusLayout(
            container: CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 100, height: 100),
            focus: .center,
            zoomMultiplier: 1,
            parallaxOffset: .zero,
            parallaxOverscan: maxParallax
        )
        let tilted = PhotoLayer.focusLayout(
            container: CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 100, height: 100),
            focus: .center,
            zoomMultiplier: 1,
            parallaxOffset: CGSize(width: 12, height: -8),
            parallaxOverscan: maxParallax
        )

        #expect(atRest.scaled == tilted.scaled)
        #expect(atRest.scaled.width >= 100 + 2 * maxParallax.width)
        #expect(atRest.scaled.height >= 100 + 2 * maxParallax.height)
        #expect(atRest.offset == .zero)
        #expect(tilted.offset == CGSize(width: 12, height: -8))
    }

    @Test @MainActor func focusAndParallaxOffsetClampToReservedImageBounds() {
        let layout = PhotoLayer.focusLayout(
            container: CGSize(width: 100, height: 100),
            imageSize: CGSize(width: 100, height: 100),
            focus: NormalizedPoint(x: 0, y: 1),
            zoomMultiplier: 1,
            parallaxOffset: CGSize(width: 20, height: -20)
        )

        let maxDX = (layout.scaled.width - 100) / 2
        let maxDY = (layout.scaled.height - 100) / 2
        #expect(layout.offset.width == maxDX)
        #expect(layout.offset.height == -maxDY)
    }
    @Test @MainActor func resizingPreservesSourcePhotoComposition() {
        let source = CGSize(width: 350, height: 200)
        let image = CGSize(width: 900, height: 1200)
        let original = PhotoLayer.focusLayout(container: source, imageSize: image,
                                             focus: NormalizedPoint(x: 0.3, y: 0.2), zoomMultiplier: 1)
        for size in [source, CGSize(width: 375, height: 500), CGSize(width: 400, height: 850)] {
            let layout = PhotoLayer.presentationLayout(container: size, framingSize: source,
                                                       imageSize: image, focus: NormalizedPoint(x: 0.3, y: 0.2),
                                                       zoomMultiplier: 1)
            #expect(abs(layout.offset.width - original.offset.width) < 0.001)
            #expect(abs(layout.offset.height - original.offset.height) < 0.001)
            #expect(layout.scaled.width + 0.001 >= size.width + 2 * abs(layout.offset.width))
            #expect(layout.scaled.height + 0.001 >= size.height + 2 * abs(layout.offset.height))
        }
    }

}
