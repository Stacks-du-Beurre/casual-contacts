import CoreModels
import CoreText
import SwiftUI

/// An encounter's engraved inscription. Identity is stable across launches and
/// edits; the inscription follows the current name and place. No new record data.
struct MicroprintInscription: Hashable {
    let identity: String
    let subject: String
    let moment: String
    let seed: UInt64

    init(record: Record) {
        var uuid = record.id.uuid
        seed = withUnsafeBytes(of: &uuid) { bytes in
            bytes.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
        }
        let hex = String(format: "%016llX", seed)
        identity = String(hex.prefix(4)) + "·" + String(hex.suffix(4))
        let name = Self.clean(record.name, limit: 64)
        let place = Self.clean(record.location?.label ?? "", limit: 64)
        subject = [name, place].filter { !$0.isEmpty }.joined(separator: "  ·  ")
        // Records do not store the encounter's timezone. Use an explicit UTC
        // inscription so travelling cannot silently re-issue a different print.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy.MM.dd  ·  HH:mm 'UTC'"
        moment = formatter.string(from: record.createdAt)
    }

    static func clean(_ text: String, limit: Int) -> String {
        let cleaned = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ").uppercased()
        return cleaned.count > limit ? String(cleaned.prefix(limit - 1)) + "…" : cleaned
    }
}

/// A single cached engraving texture. Motion never re-shapes glyphs or re-strokes
/// its registration marks. The inscription follows the nearest guilloche plane
/// to three quarters of the stack, rather than a separate scene depth.
struct CardMicroprintLayer: View {
    let record: Record
    let expansion: CGFloat
    var attitude: DeviceAttitude = .zero
    var pathCount: Int = GuillocheBlendLayer.defaultMaxDepthLayer + 1
    var minimumSide: CGFloat = 0
    nonisolated static let stackProgress = 0.75

    nonisolated static func layerIndex(pathCount: Int, reversed: Bool) -> Int {
        let last = max(0, pathCount - 1)
        let step = Int((Double(last) * stackProgress).rounded())
        return reversed ? last - step : step
    }

    nonisolated static func depthFraction(pathCount: Int, reversed: Bool) -> Double {
        CardSceneDepth.blendFraction(index: layerIndex(pathCount: pathCount, reversed: reversed),
                                    count: pathCount, reversed: reversed)
    }
    @Environment(\.windowSceneProjection) private var scene
    @Bindable private var tuning = CardBlendTuning.shared

    private var gyroOffset: CGSize {
        guard scene == nil else { return .zero }
        return GuillocheBlendLayer.offset(
            forPathIndex: Self.layerIndex(pathCount: pathCount, reversed: tuning.reverseDepthOrder),
            pathCount: pathCount, attitude: attitude, depthScale: tuning.depthScale,
            reversed: true, reverseDepthOrder: tuning.reverseDepthOrder,
            reverseMotionDirection: tuning.reverseMotionDirection,
            movementScaleX: tuning.guillocheMovementScaleX,
            movementScaleY: tuning.guillocheMovementScaleY,
            perspectiveAmount: CardElementDepthTuning.shared.perspectiveAmount)
    }

    var body: some View {
        Color.clear.overlay {
            GeometryReader { geometry in
                let side = max(minimumSide, min(226 + 150 * expansion, max(1, geometry.size.width - 12)))
                MicroprintPlate(record: record)
                    .equatable()
                    .frame(width: side, height: side)
                    .opacity(0.52 + 0.14 * expansion)
                    .offset(gyroOffset)
                    .windowDepth(Self.depthFraction(pathCount: pathCount,
                        reversed: scene?.reverseGuillocheDepthOrder ?? tuning.reverseDepthOrder))
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct MicroprintPlate: View, Equatable {
    let record: Record

    var body: some View {
        if let image = MicroprintTexture.image(for: MicroprintInscription(record: record)) {
            Image(decorative: image, scale: 3)
                .resizable()
                .renderingMode(.template)
                .interpolation(.high)
                .foregroundStyle(Color(red: 0.96, green: 0.95, blue: 0.88))
                .aspectRatio(1, contentMode: .fit)
        }
    }
}

/// Static zero-pose clearance. Bezier curves stay inside their control-point
/// hulls, so enclosing every control point encloses every blended layer.
/// Motion deliberately does not change this radius.
enum MicroprintClearance {
    static let innerRadiusFraction: CGFloat = 140.0 / 400.0
    static let gap: CGFloat = 6

    static func minimumSide(paths: [Path]) -> CGFloat {
        var radius: CGFloat = 0
        func include(_ point: CGPoint) {
            radius = max(radius, hypot(point.x - 92, point.y - 80))
        }
        for path in paths {
            path.forEach { element in
                switch element {
                case let .move(to: point), let .line(to: point): include(point)
                case let .quadCurve(to: point, control: control):
                    include(point); include(control)
                case let .curve(to: point, control1: first, control2: second):
                    include(point); include(first); include(second)
                case .closeSubpath: break
                }
            }
        }
        // The blended paths use a 0.5 pt stroke.
        return (radius + 0.25 + gap) / innerRadiusFraction
    }
}

@MainActor enum MicroprintTexture {
    private static let cache: NSCache<NSString, MicroprintImage> = {
        let cache = NSCache<NSString, MicroprintImage>()
        cache.totalCostLimit = 20 * 1024 * 1024
        cache.countLimit = 24
        return cache
    }()

    static func image(for inscription: MicroprintInscription) -> CGImage? {
        let key = ["radius-105", inscription.identity, inscription.subject, inscription.moment]
            .joined(separator: "\u{1F}") as NSString
        if let cached = cache.object(forKey: key) { return cached.image }
        let started = ProcessInfo.processInfo.systemUptime
        let side = 400.0
        guard let context = CGContext(data: nil, width: 1200, height: 1200,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: nil,
                                      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.alphaOnly.rawValue)) else { return nil }
        context.scaleBy(x: 3, y: 3)
        context.translateBy(x: side / 2, y: side / 2)
        // Keep a guaranteed empty inner circle, including fallback-font glyphs.
        let inkRegion = CGMutablePath()
        inkRegion.addRect(CGRect(x: -200, y: -200, width: 400, height: 400))
        inkRegion.addEllipse(in: CGRect(x: -140, y: -140, width: 280, height: 280))
        context.addPath(inkRegion)
        context.clip(using: .evenOdd)
        // Core Graphics' natural y-up coordinates keep Core Text outlines crisp.
        let pearl = CGColor(red: 0.96, green: 0.95, blue: 0.88, alpha: 1)
        context.setStrokeColor(pearl)
        context.setFillColor(pearl)

        let radiusScale = 1.05

        // Interrupted concentric rules open around the registration marks.
        // The breaks keep the engraving airy rather than making a border.
        for (radius, alpha, width) in [(174.0, 0.45, 0.35), (157.0, 0.35, 0.3), (151.0, 0.20, 0.3)] {
            context.setAlpha(alpha)
            context.setLineWidth(width)
            for (start, end) in [(14.0, 166.0), (194.0, 346.0)] {
                context.addArc(center: .zero, radius: radius * radiusScale,
                               startAngle: start * .pi / 180, endAngle: end * .pi / 180, clockwise: false)
                context.strokePath()
            }
        }
        // Scale divisions leave breathing room around each registration mark.
        context.setAlpha(0.48)
        context.setLineWidth(0.35)
        for index in 0..<72 where index % 18 > 2 && index % 18 < 16 {
            let angle = Double(index) * .pi / 36
            let inner = (index % 3 == 0 ? 178.5 : 181.0) * radiusScale
            context.move(to: CGPoint(x: cos(angle) * inner, y: sin(angle) * inner))
            context.addLine(to: CGPoint(x: cos(angle) * 183 * radiusScale, y: sin(angle) * 183 * radiusScale))
        }
        context.strokePath()

        context.setAlpha(0.94)
        arc(inscription.subject, radius: 162 * radiusScale, centerAngle: 90, span: 137,
            fontSize: 7.6, top: true, context: context)
        arc(inscription.moment + "   ◇   CC " + inscription.identity,
            radius: 162 * radiusScale, centerAngle: -46, span: 108,
            fontSize: 6.8, top: false, context: context)
        context.setAlpha(0.46)
        arc(inscription.subject + "  ·  " + inscription.subject,
            radius: 146 * radiusScale, centerAngle: 90, span: 128,
            fontSize: 4, top: true, context: context)
        arc("CC · " + inscription.identity + "   ·   " + inscription.identity,
            radius: 146 * radiusScale, centerAngle: -46, span: 100,
            fontSize: 4, top: false, context: context)

        // Matching registration marks keep both sides precise and understated.
        context.setAlpha(0.72)
        context.setLineWidth(0.45)
        for originalX in [-166.0, 166.0] {
            let x = originalX * radiusScale
            context.strokeEllipse(in: CGRect(x: x - 4, y: -4, width: 8, height: 8))
            context.move(to: CGPoint(x: x - 9, y: 0)); context.addLine(to: CGPoint(x: x + 9, y: 0))
            context.move(to: CGPoint(x: x, y: -9)); context.addLine(to: CGPoint(x: x, y: 9))
            context.strokePath()
        }

        guard let image = context.makeImage() else { return nil }
        cache.setObject(MicroprintImage(image), forKey: key, cost: image.bytesPerRow * image.height)
        #if os(iOS)
        PerformanceDiagnostics.shared.event("microprint_plate_prepared", values: [
            "durationMS": (ProcessInfo.processInfo.systemUptime - started) * 1000,
            "textureKB": Double(image.bytesPerRow * image.height) / 1024
        ])
        #endif
        return image
    }

    /// The moving list plane needs only its native 226 pt image, not the
    /// fullscreen texture. Downsample once; no paths or glyphs change per frame.
    static func compact(for inscription: MicroprintInscription) -> CGImage? {
        let key = ["compact-projected-radius-105", inscription.identity, inscription.subject, inscription.moment]
            .joined(separator: "\u{1F}") as NSString
        if let cached = cache.object(forKey: key) { return cached.image }
        guard let source = image(for: inscription),
              let context = CGContext(data: nil, width: 678, height: 678,
                bitsPerComponent: 8, bytesPerRow: 0, space: nil,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.alphaOnly.rawValue)) else { return nil }
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: 678, height: 678))
        guard let image = context.makeImage() else { return nil }
        cache.setObject(MicroprintImage(image), forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }

    /// Shape the complete string with Core Text, including fallback fonts and
    /// Cyrillic. Place its glyph outlines along the arc; no per-character Views.
    private static func arc(_ text: String, radius: Double, centerAngle: Double,
                            span: Double, fontSize: Double, top: Bool, context: CGContext) {
        guard !text.isEmpty else { return }
        let font = CTFontCreateWithName("IBMPlexMono-Regular" as CFString, fontSize, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTKernAttributeName as String): 0.9
        ]))
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        guard width > 0 else { return }
        let fit = min(1, radius * span * .pi / 180 / width)
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
            for index in 0..<count {
                guard let glyph = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) else { continue }
                let offset = (positions[index].x - width / 2) * fit / radius
                let angle = centerAngle * .pi / 180 + (top ? -offset : offset)
                context.saveGState()
                context.translateBy(x: cos(angle) * radius, y: sin(angle) * radius)
                context.rotate(by: angle + (top ? -.pi / 2 : .pi / 2))
                context.scaleBy(x: fit, y: fit)
                context.addPath(glyph); context.fillPath()
                context.restoreGState()
            }
        }
    }

}

private final class MicroprintImage {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}
