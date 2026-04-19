import Testing
import CoreGraphics
@testable import Visuals

@Suite struct EmptyStateGradientBackdropTests {

    /// Sunset.png (689x416) scaled-to-fill a 402x874 iPhone 17 Pro viewport:
    /// height binds, scale ≈ 2.1010, scaled width ≈ 1447.6, so slack per side
    /// is ≈ 522.8pt. This is the full pan range the painting supports.
    @Test func slackMatchesScaledToFillGeometryOnIPhone17Pro() {
        let geometry = EmptyStateGradientBackdrop.scaledGeometry(
            viewport: CGSize(width: 402, height: 874),
            imageSize: EmptyStateGradientBackdrop.imageSize
        )
        #expect(abs(geometry.width - 1447.58) < 0.5)
        #expect(geometry.height == 874)
        #expect(abs(geometry.slack - 522.79) < 0.5)
    }

    @Test func slackIsZeroWhenImageMatchesViewportAspect() {
        let geometry = EmptyStateGradientBackdrop.scaledGeometry(
            viewport: CGSize(width: 200, height: 400),
            imageSize: CGSize(width: 100, height: 200)  // same aspect
        )
        #expect(geometry.slack == 0)
    }

    @Test func slackIsZeroForDegenerateImage() {
        let geometry = EmptyStateGradientBackdrop.scaledGeometry(
            viewport: CGSize(width: 100, height: 100),
            imageSize: .zero
        )
        #expect(geometry.slack == 0)
    }

    @Test func widerImageProducesMoreSlackThanNarrowerImage() {
        let viewport = CGSize(width: 400, height: 800)
        let wide = EmptyStateGradientBackdrop.scaledGeometry(
            viewport: viewport,
            imageSize: CGSize(width: 1000, height: 400)
        )
        let narrow = EmptyStateGradientBackdrop.scaledGeometry(
            viewport: viewport,
            imageSize: CGSize(width: 600, height: 400)
        )
        #expect(wide.slack > narrow.slack)
    }
}
