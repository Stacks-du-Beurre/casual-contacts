import Testing
import Foundation
@testable import Visuals

@Suite struct VisualsBundleTests {

    @Test func bundleIsAccessible() throws {
        let bundle = CCVisuals.bundle
        // Bundle.module for an SPM target has a predictable resource path
        // We can't directly verify asset catalog contents via bundle.url(),
        // but we can verify the bundle is accessible and is not the main bundle.
        #expect(bundle.bundlePath.contains("Visuals"),
                "CCVisuals.bundle should return the Visuals module bundle")
    }
}
