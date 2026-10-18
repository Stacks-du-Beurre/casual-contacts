import Testing
import SwiftUI
import Foundation
import CoreModels
@testable import Visuals
@testable import AppFeature

@Suite struct RealCardPathProviderTests {

    @Test func microprintClearsEveryBlendStyleAtZeroPoint() {
        let provider = RealCardPathProvider()
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZЁАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")
        for letter in letters {
            for shape in GuillocheShape.allCases {
                let paths = provider.blendPaths(for: letter, shape: shape, density: .cards)
                #expect(!paths.isEmpty)
                let side = max(226, MicroprintClearance.minimumSide(paths: paths))
                let emptyRadius = side * MicroprintClearance.innerRadiusFraction
                for path in paths {
                    path.forEach { element in
                        let points: [CGPoint]
                        switch element {
                        case let .move(to: point), let .line(to: point): points = [point]
                        case let .quadCurve(to: point, control: control): points = [point, control]
                        case let .curve(to: point, control1: first, control2: second): points = [point, first, second]
                        case .closeSubpath: points = []
                        }
                        for point in points {
                            #expect(hypot(point.x - 92, point.y - 80) + 0.25 + 6 <= emptyRadius + 0.001,
                                    "Zero-pose intersection: \(letter), \(shape)")
                        }
                    }
                }
            }
        }
    }

    @Test func rotationPathsReturnNonEmptyForKnownLetter() {
        let provider = RealCardPathProvider()
        let paths = provider.rotationPaths(for: "A")
        #expect(!paths.isEmpty, "Expected generated Rotation/A paths to be non-empty — did you run Tools/regenerate-svg.sh?")
    }

    @Test func rotationPathsReturnNonEmptyForCyrillicLetter() {
        let provider = RealCardPathProvider()
        let paths = provider.rotationPaths(for: "А")
        #expect(!paths.isEmpty, "Expected generated Rotation/Cyrillic/U0410 paths to be non-empty — did you run Tools/regenerate-svg.sh?")
    }

    @Test func cyrillicRotationPathsAreFlippedUpright() {
        let provider = RealCardPathProvider()
        let rawPaths = CCVisuals.Guilloche.SVGResource.paths(named: "U0410_Rotation", kind: .rotation)
        let renderedPaths = provider.rotationPaths(for: "А")

        #expect(!rawPaths.isEmpty)
        #expect(!renderedPaths.isEmpty)
        #expect(
            renderedPaths[0].boundingRect.isApproximatelyEqual(
                to: rawPaths[0].boundingRect.flippedUprightInGuillocheViewBox
            )
        )
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

    @Test func blendPathsReturnNonEmptyForCyrillicLetter() {
        let provider = RealCardPathProvider()
        let paths = provider.blendPaths(for: "Ю", shape: .polygon, density: .cards)
        #expect(paths.count >= 10, "Cyrillic blend paths should include the generated layered stack — got \(paths.count)")
    }

    @Test func cyrillicBlendPathsAreFlippedUpright() {
        let provider = RealCardPathProvider()
        let rawPaths = CCVisuals.Guilloche.SVGResource.paths(named: "U042E_Polygon", kind: .blend)
        let renderedPaths = provider.blendPaths(for: "Ю", shape: .polygon, density: .cards)

        #expect(!rawPaths.isEmpty)
        #expect(!renderedPaths.isEmpty)
        #expect(
            renderedPaths[0].boundingRect.isApproximatelyEqual(
                to: rawPaths[0].boundingRect.flippedUprightInGuillocheViewBox
            )
        )
    }
}

private extension CGRect {
    var flippedUprightInGuillocheViewBox: CGRect {
        CGRect(
            x: minX,
            y: 160 - maxY,
            width: width,
            height: height
        )
    }

    func isApproximatelyEqual(to other: CGRect, tolerance: CGFloat = 0.01) -> Bool {
        abs(minX - other.minX) <= tolerance
            && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }
}
