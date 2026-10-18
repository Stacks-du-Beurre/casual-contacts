import SwiftUI
import Testing
import CoreModels
@testable import Visuals

@MainActor @Suite struct ProjectedGuillocheCanvasTests {
    @Test(arguments: [false, true])
    func microprintCanvasMatchesTheThreeQuarterDepthLayer(reversed: Bool) throws {
        let paths = CCVisuals.Guilloche.Blend.Latin.A_Circle.all
        let record = Record(id: UUID(uuidString: "DEBC1102-0000-0000-0000-000000000012")!,
                            name: "A", description: "", photoID: nil, location: nil, zodiacSign: nil,
                            createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0),
                            metadata: RecordMetadata(timeOfDay: .night, moonPhase: .fullMoon))
        SecurityThreadTests.registerFonts()
        let plate = try #require(MicroprintTexture.compact(for: MicroprintInscription(record: record)))
        #expect(plate.bytesPerRow * plate.height < 500_000)
        #expect(CardMicroprintLayer.depthFraction == 0.75)
        let scene = WindowSceneProjection(eye: ViewerPosition(x: 0.06, y: 0.025, distance: 0.3),
            reference: ViewerPosition(x: 0, y: 0, distance: 0.4), backingDepthMeters: 0.06,
            spacing: 1, screenWidthMeters: 0.0666, viewport: CGSize(width: 400, height: 300),
            reverseGuillocheDepthOrder: reversed)
        func render(engraved: Bool, separate: Bool = false) throws -> [UInt8] {
            let view = ZStack {
                Color.black
                GuillocheBlendLayer(paths: paths, density: .cards, attitude: .zero,
                    tint: .white, reversed: true, microprintImage: engraved ? plate : nil,
                    microprintOpacity: 0.52 / 0.55)
                    .frame(width: 184, height: 160).opacity(0.55)
                if separate { CardMicroprintLayer(record: record, expansion: 0) }
            }.frame(width: 400, height: 300).coordinateSpace(.named("CardScene"))
                .environment(\.windowCardSize, CGSize(width: 400, height: 300))
                .environment(\.windowCardFrame, CGRect(x: 0, y: 0, width: 400, height: 300))
                .environment(\.windowSceneProjection, scene).environment(\.usesProjectedGuillocheCanvas, true)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try #require(renderer.cgImage)
            var pixels = [UInt8](repeating: 0, count: 800 * 600 * 4)
            let context = try #require(CGContext(data: &pixels, width: 800, height: 600,
                bitsPerComponent: 8, bytesPerRow: 3200, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 800, height: 600))
            return pixels
        }
        let reference = try render(engraved: false, separate: true)
        let candidate = try render(engraved: true)
        let withoutPrint = try render(engraved: false)
        #expect(candidate != withoutPrint, "The projected canvas must draw the inscription")
        let error = zip(reference, candidate).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        let mean = Double(error) / Double(candidate.count)
        #expect(mean < 1, "Canvas inscription differs from the standalone 75% plane: \(mean)")
    }

    @Test(arguments: [0.0, 0.08, -0.16])
    func canvasMatchesIndividualProjectedLayers(horizontalEye: Double) throws {
        let paths = CCVisuals.Guilloche.Blend.Latin.A_Circle.all
        let scene = WindowSceneProjection(
            eye: ViewerPosition(x: horizontalEye, y: 0.025, distance: 0.28),
            reference: ViewerPosition(x: 0, y: 0, distance: 0.4),
            backingDepthMeters: 0.06, spacing: 1, screenWidthMeters: 0.0666,
            viewport: CGSize(width: 400, height: 800), reverseGuillocheDepthOrder: horizontalEye < 0,
            cardCenteredReference: true)
        func render(canvas: Bool) throws -> [UInt8] {
            let layer = GuillocheBlendLayer(paths: paths, density: .cards, attitude: .zero,
                                            tint: .white, reversed: true)
            let renderer = ImageRenderer(content:
                ZStack { Color.black; layer.frame(width: 184, height: 160) }
                    .frame(width: 400, height: 300)
                    .coordinateSpace(.named("CardScene"))
                    .environment(\.windowCardSize, CGSize(width: 400, height: 300))
                    .environment(\.windowCardFrame, CGRect(x: 0, y: 0, width: 400, height: 300))
                    .environment(\.windowSceneProjection, scene)
                    .environment(\.usesProjectedGuillocheCanvas, canvas))
            renderer.scale = 2
            let image = try #require(renderer.cgImage)
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = try #require(CGContext(data: &bytes, width: image.width, height: image.height,
                                                 bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                                 space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return bytes
        }
        let reference = try render(canvas: false)
        let candidate = try render(canvas: true)
        #expect(reference.count == candidate.count)
        let differences = zip(reference, candidate).map { abs(Int($0) - Int($1)) }
        let mean = Double(differences.reduce(0, +)) / Double(differences.count)
        let normalizedDifference = Double(differences.reduce(0, +)) / Double(max(reference.enumerated().filter { $0.offset % 4 != 3 }.reduce(0) { $0 + Int($1.element) }, 1))
        print("Canvas parity x=\(horizontalEye): mean=\(mean), normalized=\(normalizedDifference)")
        #expect(normalizedDifference < 0.1)
        #expect(mean < 1, "Mean channel difference: \(mean)")
        #expect(candidate.contains { $0 > 0 && $0 < 255 })
    }
}
