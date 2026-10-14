#if canImport(UIKit)
import CoreGraphics
import Foundation
import CoreModels
import SwiftUI
import Testing
@testable import Visuals

@Suite @MainActor struct CardMaterialSampleTests {
    @Test func liveMaterialRetainsOriginalBlurAppearance() throws {
        let size = CGSize(width: 240, height: 180)
        let wallpaper = LinearGradient(colors: [.blue, .red, .green],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
        func render(cachedMaterial: Bool) throws -> CGImage {
            let view = wallpaper.overlay(alignment: .bottomLeading) {
                HologramText("JANE", font: .system(size: 24), attitude: .zero,
                             backdropSize: size, coordinateSpaceName: "CardScene") {
                    if cachedMaterial {
                        CardMaterialSample(recordKey: 0, attitude: .zero, paused: false,
                                           size: size, frame: CGRect(origin: .zero, size: size)) { _, _ in wallpaper }
                    } else {
                        wallpaper
                    }
                }
                .padding(12)
            }
            .frame(width: size.width, height: size.height)
            .coordinateSpace(.named("CardScene"))
            .environment(\.usesCachedCardMaterials, cachedMaterial)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            return try #require(renderer.cgImage)
        }
        let original = try render(cachedMaterial: false)
        let optimized = try render(cachedMaterial: true)
        let first = try #require(original.dataProvider?.data)
        let second = try #require(optimized.dataProvider?.data)
        #expect(CFDataGetLength(first) == CFDataGetLength(second))
        let a = try #require(CFDataGetBytePtr(first))
        let b = try #require(CFDataGetBytePtr(second))
        let count = CFDataGetLength(first)
        let averageError = (0..<count).reduce(0.0) { $0 + Double(abs(Int(a[$1]) - Int(b[$1]))) } / Double(count)
        #expect(averageError < 1)
    }

    @Test func staticSampleContainsGuillocheWithoutWaitingForReveal() throws {
        let record = Record(id: UUID(), name: "A", description: "", photoID: nil,
                            location: nil, zodiacSign: nil, createdAt: .distantPast,
                            updatedAt: .distantPast,
                            metadata: RecordMetadata(timeOfDay: .night, moonPhase: .fullMoon))
        func render(ink: Bool) throws -> CGImage {
            let renderer = ImageRenderer(content: CardBackdrop(
                record: record, attitude: .zero, paths: MaterialSamplePaths(),
                showsGuilloche: ink, isStaticSample: true
            ).frame(width: 240, height: 180).clipped())
            renderer.scale = 1
            return try #require(renderer.cgImage)
        }
        let withInk = try render(ink: true)
        let withoutInk = try render(ink: false)
        #expect(withInk.width == 240)
        #expect(withInk.height == 180)
        let first = try #require(withInk.dataProvider?.data)
        let second = try #require(withoutInk.dataProvider?.data)
        #expect(CFDataGetLength(first) == CFDataGetLength(second))
        let a = try #require(CFDataGetBytePtr(first))
        let b = try #require(CFDataGetBytePtr(second))
        let changed = (0..<CFDataGetLength(first)).filter { abs(Int(a[$0]) - Int(b[$0])) > 3 }.count
        #expect(changed > 100)
    }
}

private struct MaterialSamplePaths: CardPathProvider {
    func rotationPaths(for letter: Character) -> [Path] {
        [Path(ellipseIn: CGRect(x: 10, y: 10, width: 160, height: 130))]
    }
    func blendPaths(for letter: Character, shape: GuillocheShape,
                    density: CCVisuals.Guilloche.LineDensity) -> [Path] {
        rotationPaths(for: letter)
    }
}
#endif
