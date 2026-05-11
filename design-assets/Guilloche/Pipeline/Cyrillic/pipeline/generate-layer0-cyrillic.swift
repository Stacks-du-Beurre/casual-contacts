import CoreGraphics
import CoreText
import Foundation

struct Segment {
    enum Kind {
        case line(CGPoint)
        case quad(CGPoint, CGPoint)
        case cubic(CGPoint, CGPoint, CGPoint)
    }

    let kind: Kind
}

struct Contour {
    var start: CGPoint
    var segments: [Segment] = []
    var isClosed = false
}

struct GlyphSpec {
    let character: Character
    let sourceCharacter: Character
    let note: String?
}

struct PixelPoint: Hashable {
    let x: Int
    let y: Int
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let pipelineDir = scriptURL.deletingLastPathComponent()
let repoRoot = pipelineDir
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let fontURL = repoRoot
    .appendingPathComponent("Packages/Sources/DesignSystem/Resources/Fonts/CormorantSC-SemiBold.ttf")
let outputDir = pipelineDir.appendingPathComponent("glyph-outlines/layer-0")

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

guard let provider = CGDataProvider(url: fontURL as CFURL),
      let cgFont = CGFont(provider)
else {
    fputs("Failed to load font at \(fontURL.path)\n", stderr)
    exit(1)
}

let font = CTFontCreateWithGraphicsFont(cgFont, 1000, nil, nil)

let characters: [GlyphSpec] = [
    .init(character: "А", sourceCharacter: "А", note: nil),
    .init(character: "Б", sourceCharacter: "Б", note: nil),
    .init(character: "В", sourceCharacter: "В", note: nil),
    .init(character: "Г", sourceCharacter: "Г", note: nil),
    .init(character: "Д", sourceCharacter: "Д", note: nil),
    .init(character: "Е", sourceCharacter: "Е", note: nil),
    .init(character: "Ё", sourceCharacter: "Е", note: "temporary base Е outline; dots intentionally excluded from blend source"),
    .init(character: "Ж", sourceCharacter: "Ж", note: nil),
    .init(character: "З", sourceCharacter: "З", note: nil),
    .init(character: "И", sourceCharacter: "И", note: nil),
    .init(character: "Й", sourceCharacter: "И", note: "temporary base И outline; breve intentionally excluded from blend source"),
    .init(character: "К", sourceCharacter: "К", note: nil),
    .init(character: "Л", sourceCharacter: "Л", note: nil),
    .init(character: "М", sourceCharacter: "М", note: nil),
    .init(character: "Н", sourceCharacter: "Н", note: nil),
    .init(character: "О", sourceCharacter: "О", note: nil),
    .init(character: "П", sourceCharacter: "П", note: nil),
    .init(character: "Р", sourceCharacter: "Р", note: nil),
    .init(character: "С", sourceCharacter: "С", note: nil),
    .init(character: "Т", sourceCharacter: "Т", note: nil),
    .init(character: "У", sourceCharacter: "У", note: nil),
    .init(character: "Ф", sourceCharacter: "Ф", note: nil),
    .init(character: "Х", sourceCharacter: "Х", note: nil),
    .init(character: "Ц", sourceCharacter: "Ц", note: nil),
    .init(character: "Ч", sourceCharacter: "Ч", note: nil),
    .init(character: "Ш", sourceCharacter: "Ш", note: nil),
    .init(character: "Щ", sourceCharacter: "Щ", note: nil),
    .init(character: "Ъ", sourceCharacter: "Ъ", note: nil),
    .init(character: "Ы", sourceCharacter: "Ы", note: nil),
    .init(character: "Ь", sourceCharacter: "Ь", note: nil),
    .init(character: "Э", sourceCharacter: "Э", note: nil),
    .init(character: "Ю", sourceCharacter: "Ю", note: nil),
    .init(character: "Я", sourceCharacter: "Я", note: nil),
]

for spec in characters {
    guard let glyphPath = path(for: spec.sourceCharacter, font: font) else {
        fputs("No glyph path for \(spec.character)\n", stderr)
        continue
    }

    let normalizedPath = normalize(path: glyphPath)
    let contours = tracedExteriorContours(from: normalizedPath)
    guard !contours.isEmpty else {
        fputs("No exterior contours for \(spec.character)\n", stderr)
        continue
    }

    let svg = svgDocument(for: spec, contours: contours)
    let codepoint = spec.character.unicodeScalars.first!.value
    let fileURL = outputDir.appendingPathComponent(String(format: "U%04X_layer_0.svg", codepoint))
    try svg.write(to: fileURL, atomically: true, encoding: .utf8)
    print("Generated \(fileURL.path)")
}

func path(for character: Character, font: CTFont) -> CGPath? {
    let utf16 = Array(String(character).utf16)
    var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
    guard CTFontGetGlyphsForCharacters(font, utf16, &glyphs, utf16.count),
          let glyph = glyphs.first,
          glyph != 0
    else {
        return nil
    }
    return CTFontCreatePathForGlyph(font, glyph, nil)
}

func normalize(path: CGPath) -> CGPath {
    let glyphBounds = path.boundingBoxOfPath
    let maxWidth: CGFloat = 136
    let maxHeight: CGFloat = 112
    let scale = min(maxWidth / glyphBounds.width, maxHeight / glyphBounds.height)
    let center = CGPoint(x: 92, y: 80)
    var transform = CGAffineTransform(
        a: scale,
        b: 0,
        c: 0,
        d: -scale,
        tx: center.x - glyphBounds.midX * scale,
        ty: center.y + glyphBounds.midY * scale
    )
    return path.copy(using: &transform) ?? path
}

func tracedExteriorContours(from normalizedPath: CGPath) -> [Contour] {
    let rasterScale = 12
    let width = 184 * rasterScale
    let height = 160 * rasterScale
    let mask = rasterMask(for: normalizedPath, width: width, height: height, scale: rasterScale)
    let loops = boundaryLoops(in: mask, width: width, height: height)
        .compactMap { loop -> [CGPoint]? in
            let points = loop.map { CGPoint(x: CGFloat($0.x) / CGFloat(rasterScale), y: CGFloat($0.y) / CGFloat(rasterScale)) }
            let simplified = simplifyClosedLoop(points, epsilon: 0.16)
            return simplified.count >= 3 && abs(area(of: simplified)) >= 4 ? canonicalized(points: simplified) : nil
        }

    let exteriorLoops = loops.enumerated().compactMap { index, loop -> [CGPoint]? in
        guard let probe = centroid(of: loop) else { return nil }
        let isInsideLargerLoop = loops.enumerated().contains { otherIndex, otherLoop in
            guard otherIndex != index else { return false }
            return abs(area(of: otherLoop)) > abs(area(of: loop)) && contains(point: probe, in: otherLoop)
        }
        return isInsideLargerLoop ? nil : loop
    }

    return exteriorLoops
        .sorted { lhs, rhs in
            if abs(area(of: lhs)) == abs(area(of: rhs)) {
                return (lhs.first?.x ?? 0, lhs.first?.y ?? 0) < (rhs.first?.x ?? 0, rhs.first?.y ?? 0)
            }
            return abs(area(of: lhs)) > abs(area(of: rhs))
        }
        .map(contour(from:))
}

func rasterMask(for path: CGPath, width: Int, height: Int, scale: Int) -> [Bool] {
    var pixels = [UInt8](repeating: 0, count: width * height)
    let colorSpace = CGColorSpaceCreateDeviceGray()
    guard let context = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else {
        fputs("Failed to create raster context\n", stderr)
        exit(1)
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.setFillColor(gray: 1, alpha: 1)
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    context.addPath(path)
    context.fillPath(using: .winding)

    return pixels.map { $0 > 32 }
}

func boundaryLoops(in mask: [Bool], width: Int, height: Int) -> [[PixelPoint]] {
    var edges: [PixelPoint: [PixelPoint]] = [:]

    func isFilled(_ x: Int, _ y: Int) -> Bool {
        guard x >= 0, x < width, y >= 0, y < height else { return false }
        return mask[y * width + x]
    }

    func addEdge(from start: PixelPoint, to end: PixelPoint) {
        edges[start, default: []].append(end)
    }

    for y in 0..<height {
        for x in 0..<width where isFilled(x, y) {
            if !isFilled(x, y - 1) {
                addEdge(from: PixelPoint(x: x, y: y), to: PixelPoint(x: x + 1, y: y))
            }
            if !isFilled(x + 1, y) {
                addEdge(from: PixelPoint(x: x + 1, y: y), to: PixelPoint(x: x + 1, y: y + 1))
            }
            if !isFilled(x, y + 1) {
                addEdge(from: PixelPoint(x: x + 1, y: y + 1), to: PixelPoint(x: x, y: y + 1))
            }
            if !isFilled(x - 1, y) {
                addEdge(from: PixelPoint(x: x, y: y + 1), to: PixelPoint(x: x, y: y))
            }
        }
    }

    var loops: [[PixelPoint]] = []

    while let start = edges.keys.first, let firstEnd = popEdge(from: start, in: &edges) {
        var loop = [start, firstEnd]
        var current = firstEnd

        while current != start, let next = popEdge(from: current, in: &edges) {
            loop.append(next)
            current = next
        }

        if loop.count > 3, loop.last == start {
            loop.removeLast()
            loops.append(loop)
        }
    }

    return loops
}

func popEdge(from start: PixelPoint, in edges: inout [PixelPoint: [PixelPoint]]) -> PixelPoint? {
    guard var destinations = edges[start], !destinations.isEmpty else { return nil }
    let destination = destinations.removeLast()
    edges[start] = destinations.isEmpty ? nil : destinations
    return destination
}

func contour(from points: [CGPoint]) -> Contour {
    Contour(
        start: points[0],
        segments: points.dropFirst().map { Segment(kind: .line($0)) },
        isClosed: true
    )
}

func canonicalized(points: [CGPoint]) -> [CGPoint] {
    guard let startIndex = points.indices.min(by: { lhs, rhs in
        if points[lhs].y == points[rhs].y {
            return points[lhs].x < points[rhs].x
        }
        return points[lhs].y < points[rhs].y
    }) else {
        return points
    }
    return Array(points[startIndex...]) + Array(points[..<startIndex])
}

func simplifyClosedLoop(_ points: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
    guard points.count > 3 else { return points }
    let withoutCollinear = removeCollinear(points)
    guard withoutCollinear.count > 3 else { return withoutCollinear }
    let anchorIndex = withoutCollinear.indices.min(by: { lhs, rhs in
        if withoutCollinear[lhs].x == withoutCollinear[rhs].x {
            return withoutCollinear[lhs].y < withoutCollinear[rhs].y
        }
        return withoutCollinear[lhs].x < withoutCollinear[rhs].x
    }) ?? 0
    let rotated = Array(withoutCollinear[anchorIndex...]) + Array(withoutCollinear[..<anchorIndex])
    let open = rotated + [rotated[0]]
    let simplified = ramerDouglasPeucker(open, epsilon: epsilon)
    return Array(simplified.dropLast())
}

func removeCollinear(_ points: [CGPoint]) -> [CGPoint] {
    guard points.count > 2 else { return points }
    return points.indices.compactMap { index in
        let previous = points[(index - 1 + points.count) % points.count]
        let current = points[index]
        let next = points[(index + 1) % points.count]
        let cross = (current.x - previous.x) * (next.y - current.y) - (current.y - previous.y) * (next.x - current.x)
        return abs(cross) < 0.0001 ? nil : current
    }
}

func ramerDouglasPeucker(_ points: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
    guard points.count > 2 else { return points }

    let start = points[0]
    let end = points[points.count - 1]
    var maxDistance: CGFloat = 0
    var index = 0

    for i in 1..<(points.count - 1) {
        let distance = perpendicularDistance(from: points[i], toLineStart: start, lineEnd: end)
        if distance > maxDistance {
            index = i
            maxDistance = distance
        }
    }

    if maxDistance > epsilon {
        let left = ramerDouglasPeucker(Array(points[0...index]), epsilon: epsilon)
        let right = ramerDouglasPeucker(Array(points[index...]), epsilon: epsilon)
        return left.dropLast() + right
    }

    return [start, end]
}

func perpendicularDistance(from point: CGPoint, toLineStart start: CGPoint, lineEnd end: CGPoint) -> CGFloat {
    let dx = end.x - start.x
    let dy = end.y - start.y
    guard dx != 0 || dy != 0 else {
        return hypot(point.x - start.x, point.y - start.y)
    }
    return abs(dy * point.x - dx * point.y + end.x * start.y - end.y * start.x) / hypot(dx, dy)
}

func centroid(of points: [CGPoint]) -> CGPoint? {
    guard !points.isEmpty else { return nil }
    let sum = points.reduce(CGPoint.zero) { partial, point in
        CGPoint(x: partial.x + point.x, y: partial.y + point.y)
    }
    return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
}

func area(of points: [CGPoint]) -> CGFloat {
    guard points.count > 2 else { return 0 }
    return zip(points, points.dropFirst() + points.prefix(1)).reduce(0) { partial, pair in
        partial + pair.0.x * pair.1.y - pair.1.x * pair.0.y
    } / 2
}

func contains(point: CGPoint, in polygon: [CGPoint]) -> Bool {
    guard polygon.count > 2 else { return false }
    var inside = false
    var j = polygon.count - 1

    for i in polygon.indices {
        let pi = polygon[i]
        let pj = polygon[j]
        let intersects = ((pi.y > point.y) != (pj.y > point.y))
            && (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x)
        if intersects { inside.toggle() }
        j = i
    }

    return inside
}

func svgDocument(for spec: GlyphSpec, contours: [Contour]) -> String {
    let codepoint = spec.character.unicodeScalars.first!.value
    let note = spec.note.map { "\n  <!-- \($0) -->" } ?? ""

    return """
    <?xml version="1.0" encoding="UTF-8"?>
    <svg id="U\(hex(codepoint))_layer_0" data-character="\(spec.character)" data-source-character="\(spec.sourceCharacter)" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 184 160">\(note)
      <defs>
        <style>
          .cls-1 {
            fill: none;
            stroke: #000;
            stroke-miterlimit: 10;
            stroke-width: .5px;
          }
        </style>
      </defs>
      <path id="U\(hex(codepoint))_layer_0_outline" class="cls-1" d="\(pathData(for: contours))"/>
    </svg>

    """
}

func pathData(for contours: [Contour]) -> String {
    contours.map { contour in
        var parts = ["M\(number(contour.start.x)),\(number(contour.start.y))"]
        for segment in contour.segments {
            switch segment.kind {
            case let .line(point):
                parts.append("L\(number(point.x)),\(number(point.y))")
            case let .quad(control, point):
                parts.append("Q\(number(control.x)),\(number(control.y)) \(number(point.x)),\(number(point.y))")
            case let .cubic(control1, control2, point):
                parts.append("C\(number(control1.x)),\(number(control1.y)) \(number(control2.x)),\(number(control2.y)) \(number(point.x)),\(number(point.y))")
            }
        }
        if contour.isClosed {
            parts.append("Z")
        }
        return parts.joined(separator: " ")
    }
    .joined(separator: " ")
}

func number(_ value: CGFloat) -> String {
    let rounded = (Double(value) * 1000).rounded() / 1000
    return String(format: "%.3f", rounded)
        .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
}

func hex(_ value: UInt32) -> String {
    String(format: "%04X", value)
}
