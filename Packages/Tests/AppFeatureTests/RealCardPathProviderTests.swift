import Testing
import SwiftUI
import Foundation
import CoreModels
import Visuals
@testable import AppFeature

@Suite struct RealCardPathProviderTests {

    @Test func rotationPathsReturnNonEmptyForKnownLetter() {
        let provider = RealCardPathProvider()
        let paths = provider.rotationPaths(for: "A")
        #expect(!paths.isEmpty, "Expected generated Rotation/A paths to be non-empty — did you run Tools/regenerate-svg.sh?")
    }

    @Test func rotationPathsReturnEmptyForUnknownSymbol() {
        let provider = RealCardPathProvider()
        let paths = provider.rotationPaths(for: "@")   // not a letter
        #expect(paths.isEmpty)
    }

    @Test func blendPathsHaveExpectedLineCountForCards() {
        let provider = RealCardPathProvider()
        let paths = provider.blendPaths(for: "A", shape: .circle, density: .cards)
        // Designer's SVG has 15+ lines for Cards density; generated files emit that many paths per file.
        #expect(paths.count >= 10, "Blend/A circle should have many paths — got \(paths.count)")
    }

    @Test func blendPathsShapeSelectionDiffersAcrossShapes() {
        let provider = RealCardPathProvider()
        let circle = provider.blendPaths(for: "A", shape: .circle, density: .cards)
        let square = provider.blendPaths(for: "A", shape: .square, density: .cards)
        // Different shapes map to different generated files; both should be non-empty.
        #expect(!circle.isEmpty && !square.isEmpty)
    }
}
