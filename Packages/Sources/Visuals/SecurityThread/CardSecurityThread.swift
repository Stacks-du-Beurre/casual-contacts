import CoreModels
import SwiftUI

/// A continuous ribbon. Encounter date sets its colour; the viewpoint reveals
/// soft waves of reflection. Cached engraving carries no readable information.
struct CardSecurityThread: View {
    let record: Record
    let attitude: DeviceAttitude
    let expansion: CGFloat
    @Environment(\.windowSceneProjection) private var scene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var prepared: SecurityThreadPrepared?

    var body: some View {
        let inscription = SecurityThreadInscription(record: record)
        let light = reduceMotion ? .zero : SecurityThreadLight(scene: scene, attitude: attitude)
        Color.clear.overlay {
            if let prepared {
                SecurityThreadSurface(inscription: inscription, light: light, expansion: expansion,
                                      preparedImage: prepared.engraving)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: inscription) {
            let value = await Task.detached(priority: .userInitiated) {
                SecurityThreadPrepared(inscription: inscription)
            }.value
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { prepared = value }
        }
        .onDisappear { prepared = nil }
    }
}

struct SecurityThreadInscription: Hashable, Sendable {
    let annualPhase: Double
    let variation: Int

    init(record: Record) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.ordinality(of: .day, in: .year, for: record.createdAt) ?? 1
        let days = calendar.range(of: .day, in: .year, for: record.createdAt)?.count ?? 365
        annualPhase = Double(day - 1) / Double(days)
        var uuid = record.id.uuid
        variation = withUnsafeBytes(of: &uuid) { bytes in
            bytes.enumerated().reduce(0) { $0 + ($1.offset + 1) * Int($1.element) } % 23
        }
    }

    // Geometry is shared across dates; colour does not require a new texture.
    var cacheKey: String { "annual-silk-1-\(variation)" }
}

struct SecurityThreadPalette: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(annualPhase: Double) {
        let stops = [(112.0, 162.0, 194.0), (125, 190, 153), (224, 198, 130), (199, 135, 113)]
        let phase = annualPhase.isFinite ? annualPhase - floor(annualPhase) : 0
        let position = phase * 4
        let index = Int(position) % 4
        let amount = position - floor(position)
        let a = stops[index], b = stops[(index + 1) % 4]
        red = (a.0 + (b.0 - a.0) * amount) / 255
        green = (a.1 + (b.1 - a.1) * amount) / 255
        blue = (a.2 + (b.2 - a.2) * amount) / 255
    }

    func colour(highlight: Double, opacity: Double) -> Color {
        Color(red: red + (247.0 / 255 - red) * highlight,
              green: green + (242.0 / 255 - green) * highlight,
              blue: blue + (216.0 / 255 - blue) * highlight).opacity(opacity)
    }
}

struct SecurityThreadPrepared: Sendable {
    let engraving: CGImage?
    init(inscription: SecurityThreadInscription) {
        engraving = SecurityThreadEngraving.image(for: inscription)
    }
}

struct SecurityThreadLight: Equatable {
    let horizontal: Double
    let vertical: Double
    static let zero = Self(horizontal: 0, vertical: 0)
    var phase: Double { horizontal * 2.4 + vertical * 3.8 }

    init(horizontal: Double, vertical: Double) {
        self.horizontal = min(1, max(-1, horizontal.isFinite ? horizontal : 0))
        self.vertical = min(1, max(-1, vertical.isFinite ? vertical : 0))
    }

    init(scene: WindowSceneProjection?, attitude: DeviceAttitude) {
        if let scene {
            self.init(horizontal: atan2(scene.eye.x, max(0.05, scene.eye.distance)) * 2.4,
                      vertical: atan2(scene.eye.y, max(0.05, scene.eye.distance)) * 2)
        } else {
            self.init(horizontal: attitude.roll, vertical: attitude.pitch)
        }
    }
}

struct SecurityThreadCompact: View {
    let inscription: SecurityThreadInscription
    let light: SecurityThreadLight
    var body: some View {
        SecurityThreadSurface(inscription: inscription, light: light, expansion: 0)
    }
}

/// One shaded, cached image in both list and fullscreen. No tessellation,
/// backdrop blur, separate glint pass, or idle timer runs during motion.
struct SecurityThreadSurface: View {
    let inscription: SecurityThreadInscription
    let light: SecurityThreadLight
    let expansion: CGFloat
    var preparedImage: CGImage? = nil

    var body: some View {
        let plate = preparedImage ?? SecurityThreadEngraving.image(for: inscription)
        let palette = SecurityThreadPalette(annualPhase: inscription.annualPhase)
        let stops = (0...64).map { index -> Gradient.Stop in
            let t = Double(index) / 64
            let wave = (1 + cos(t * .pi * 2 * 2.15 - light.phase)) / 2
            let envelope = pow(wave, 2.1)
            let rim = pow(max(0, cos(t * .pi * 2 * 2.15 - light.phase - 0.5)), 10)
            let endFade = min(1, t * 22, (1 - t) * 22)
            return .init(color: palette.colour(highlight: 0.12 + rim * 0.52,
                opacity: (0.008 + envelope * 0.96) * endFade), location: t)
        }
        Canvas { context, size in
            guard let plate else { return }
            let t = min(1, max(0, expansion))
            let width = 12 + 26 * t
            let height = size.height * (0.78 - 0.21 * t)
            let frame = CGRect(x: size.width - width - 12 * t,
                y: size.height * (0.11 + 0.05 * t), width: width, height: height)
            var ink = context.resolve(Image(decorative: plate, scale: 3))
            ink.shading = .linearGradient(Gradient(stops: stops),
                startPoint: frame.origin, endPoint: CGPoint(x: frame.minX + width * 0.18, y: frame.maxY))
            context.draw(ink, in: frame)
        }
    }
}

enum SecurityThreadEngraving {
    private static let cache = SecurityThreadCache()

    static func image(for inscription: SecurityThreadInscription) -> CGImage? {
        let key = inscription.cacheKey as NSString
        if let value = cache.storage.object(forKey: key) { return value.image }
        let start = ProcessInfo.processInfo.systemUptime
        guard let context = CGContext(data: nil, width: 192, height: 1920,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: nil,
                                      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.alphaOnly.rawValue)) else { return nil }
        context.scaleBy(x: 3, y: 3)
        context.translateBy(x: 0, y: 640)
        context.scaleBy(x: 1, y: -1)
        context.setStrokeColor(CGColor(gray: 1, alpha: 1))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        let shape = CGMutablePath()
        for step in 0...240 {
            let t = Double(step) / 240
            let point = CGPoint(x: 14 + sin(t * .pi * 2 - 0.4) * 2, y: t * 640)
            if step == 0 { shape.move(to: point) } else { shape.addLine(to: point) }
        }
        for step in (0...240).reversed() {
            let t = Double(step) / 240
            shape.addLine(to: CGPoint(x: 50 + sin(t * .pi * 2 - 0.4) * 2, y: t * 640))
        }
        shape.closeSubpath()
        context.addPath(shape)
        context.clip()
        context.setAlpha(0.72)
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 640))
        context.setBlendMode(.destinationOut)
        context.setAlpha(0.68)
        context.setLineWidth(0.32)
        let phase = Double(inscription.variation) / 23 * 0.2
        for line in -22..<295 {
            for step in 0...90 {
                let x = 9 + Double(step) * 0.52
                let y = Double(line) * 2.35 + sin(x / 64 * .pi * 1.8 + Double(line) * 0.035 + phase) * 15
                if step == 0 { context.move(to: CGPoint(x: x, y: y)) }
                else { context.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.strokePath()
        }
        context.setAlpha(0.25)
        context.setLineWidth(0.18)
        for line in 0..<65 {
            context.move(to: CGPoint(x: line, y: 0))
            context.addLine(to: CGPoint(x: line - 18, y: 640))
            context.strokePath()
        }
        guard let image = context.makeImage() else { return nil }
        cache.storage.setObject(SecurityThreadImage(image), forKey: key, cost: image.bytesPerRow * image.height)
        #if os(iOS)
        let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1000
        let textureKB = Double(image.bytesPerRow * image.height) / 1024
        Task { @MainActor in
            PerformanceDiagnostics.shared.event("security_thread_prepared", values: [
                "durationMS": elapsed, "textureKB": textureKB
            ])
        }
        #endif
        return image
    }
}

private final class SecurityThreadImage {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}

private final class SecurityThreadCache: @unchecked Sendable {
    let storage: NSCache<NSString, SecurityThreadImage> = {
        let cache = NSCache<NSString, SecurityThreadImage>()
        cache.totalCostLimit = 12 * 1024 * 1024
        cache.countLimit = 24
        return cache
    }()
}
