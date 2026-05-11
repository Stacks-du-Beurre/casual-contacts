import CoreGraphics
import CoreText
import Foundation

struct GlyphSpec {
    let character: Character
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
let outputDir = pipelineDir.appendingPathComponent("rotation-sources")
let previewDir = pipelineDir.appendingPathComponent("rotation-previews")

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: previewDir, withIntermediateDirectories: true)

guard let provider = CGDataProvider(url: fontURL as CFURL),
      let cgFont = CGFont(provider)
else {
    fputs("Failed to load font at \(fontURL.path)\n", stderr)
    exit(1)
}

let font = CTFontCreateWithGraphicsFont(cgFont, 1000, nil, nil)

let characters: [GlyphSpec] = [
    .init(character: "А"),
    .init(character: "Б"),
    .init(character: "В"),
    .init(character: "Г"),
    .init(character: "Д"),
    .init(character: "Е"),
    .init(character: "Ё"),
    .init(character: "Ж"),
    .init(character: "З"),
    .init(character: "И"),
    .init(character: "Й"),
    .init(character: "К"),
    .init(character: "Л"),
    .init(character: "М"),
    .init(character: "Н"),
    .init(character: "О"),
    .init(character: "П"),
    .init(character: "Р"),
    .init(character: "С"),
    .init(character: "Т"),
    .init(character: "У"),
    .init(character: "Ф"),
    .init(character: "Х"),
    .init(character: "Ц"),
    .init(character: "Ч"),
    .init(character: "Ш"),
    .init(character: "Щ"),
    .init(character: "Ъ"),
    .init(character: "Ы"),
    .init(character: "Ь"),
    .init(character: "Э"),
    .init(character: "Ю"),
    .init(character: "Я"),
]

let previewCharacters: Set<Character> = ["А", "Ё", "Ж", "Й", "О", "Ф", "Ы", "Ю"]

for spec in characters {
    guard let glyphPath = path(for: spec.character, font: font) else {
        fputs("No glyph path for \(spec.character)\n", stderr)
        continue
    }

    let normalizedPath = normalizeForRotation(path: glyphPath)
    let pathData = pathData(for: tracedExteriorLoops(from: normalizedPath))
    guard !pathData.isEmpty else {
        fputs("No SVG path data for \(spec.character)\n", stderr)
        continue
    }

    let codepoint = spec.character.unicodeScalars.first!.value
    let code = hex(codepoint)
    let sourceSVG = rotationSourceSVG(character: spec.character, code: code, pathData: pathData)
    let fileURL = outputDir.appendingPathComponent("U\(code)_Rotation.svg")
    try sourceSVG.write(to: fileURL, atomically: true, encoding: .utf8)

    if previewCharacters.contains(spec.character) {
        let previewSVG = rosettePreviewSVG(character: spec.character, code: code, pathData: pathData)
        let previewURL = previewDir.appendingPathComponent("U\(code)_Rotation_rosette.svg")
        try previewSVG.write(to: previewURL, atomically: true, encoding: .utf8)
    }

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

func normalizeForRotation(path: CGPath) -> CGPath {
    let glyphBounds = path.boundingBoxOfPath
    let maxWidth: CGFloat = 330
    let maxHeight: CGFloat = 189.5
    let scale = min(maxWidth / glyphBounds.width, maxHeight / glyphBounds.height)
    let centerX: CGFloat = 190
    let bottomY: CGFloat = 190

    var transform = CGAffineTransform(
        a: scale,
        b: 0,
        c: 0,
        d: -scale,
        tx: centerX - glyphBounds.midX * scale,
        ty: bottomY + glyphBounds.minY * scale
    )
    return path.copy(using: &transform) ?? path
}

func tracedExteriorLoops(from normalizedPath: CGPath) -> [[CGPoint]] {
    let rasterScale = 6
    let width = 380 * rasterScale
    let height = 380 * rasterScale
    let mask = rasterMask(for: normalizedPath, width: width, height: height, scale: rasterScale)
    let loops = boundaryLoops(in: mask, width: width, height: height)
        .compactMap { loop -> [CGPoint]? in
            let points = loop.map {
                CGPoint(
                    x: CGFloat($0.x) / CGFloat(rasterScale),
                    y: CGFloat(height - $0.y) / CGFloat(rasterScale)
                )
            }
            let simplified = simplifyClosedLoop(points, epsilon: 0.22)
            return simplified.count >= 3 && abs(area(of: simplified)) >= 4 ? canonicalized(points: simplified) : nil
        }

    return loops.enumerated()
        .compactMap { index, loop -> [CGPoint]? in
            guard let probe = centroid(of: loop) else { return nil }
            let isInsideLargerLoop = loops.enumerated().contains { otherIndex, otherLoop in
                guard otherIndex != index else { return false }
                return abs(area(of: otherLoop)) > abs(area(of: loop)) && contains(point: probe, in: otherLoop)
            }
            return isInsideLargerLoop ? nil : loop
        }
        .sorted { lhs, rhs in
            if abs(area(of: lhs)) == abs(area(of: rhs)) {
                return (lhs.first?.x ?? 0, lhs.first?.y ?? 0) < (rhs.first?.x ?? 0, rhs.first?.y ?? 0)
            }
            return abs(area(of: lhs)) > abs(area(of: rhs))
        }
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

func pathData(for loops: [[CGPoint]]) -> String {
    loops.map(pathData(for:)).joined(separator: " ")
}

func pathData(for points: [CGPoint]) -> String {
    guard let first = points.first else { return "" }
    var parts = ["M\(number(first.x)),\(number(first.y))"]
    for point in points.dropFirst() {
        parts.append("L\(number(point.x)),\(number(point.y))")
    }
    parts.append("Z")
    return parts.joined(separator: " ")
}

func rotationSourceSVG(character: Character, code: String, pathData: String) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <svg id="U\(code)_Rotation" data-character="\(character)" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 380">
      <defs>
        <style>
          .cls-1 {
            fill: none;
            stroke: #1D1D1B;
            stroke-miterlimit: 10;
            stroke-width: .5px;
          }
        </style>
      </defs>
      <path id="U\(code)_Rotation_outline" class="cls-1" d="\(pathData)"/>
    </svg>

    """
}

func rosettePreviewSVG(character: Character, code: String, pathData: String) -> String {
    let copies = (0..<72).map { index in
        let degrees = number(CGFloat(index * 5))
        return #"    <path class="cls-1" transform="rotate(\#(degrees) 190 190)" d="\#(pathData)"/>"#
    }
    .joined(separator: "\n")

    return """
    <?xml version="1.0" encoding="UTF-8"?>
    <svg id="U\(code)_Rotation_rosette" data-character="\(character)" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 380 380">
      <defs>
        <style>
          .cls-1 {
            fill: none;
            stroke: #1D1D1B;
            stroke-miterlimit: 10;
            stroke-width: .5px;
            opacity: .2;
          }
        </style>
      </defs>
    \(copies)
    </svg>

    """
}

func number(_ value: CGFloat) -> String {
    let rounded = (Double(value) * 1000).rounded() / 1000
    return String(format: "%.3f", rounded)
        .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
}

func hex(_ value: UInt32) -> String {
    String(format: "%04X", value)
}
