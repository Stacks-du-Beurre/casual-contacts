import CoreGraphics
import Foundation

struct Variant {
    let name: String
    let suffix: String
    let seedURL: URL
}

struct SVGPath {
    var points: [CGPoint]
}

enum PipelineError: Error, CustomStringConvertible {
    case missingShape(URL)
    case malformedSVG(URL)
    case unsupportedCommand(Character)
    case malformedPath(String)
    case emptyPath(URL)

    var description: String {
        switch self {
        case let .missingShape(url):
            return "No supported path or polygon found in \(url.path)"
        case let .malformedSVG(url):
            return "Malformed SVG at \(url.path)"
        case let .unsupportedCommand(command):
            return "Unsupported SVG path command: \(command)"
        case let .malformedPath(message):
            return "Malformed SVG path: \(message)"
        case let .emptyPath(url):
            return "No points found in \(url.path)"
        }
    }
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let pipelineDir = scriptURL.deletingLastPathComponent()
let repoRoot = pipelineDir
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let glyphDir = pipelineDir.appendingPathComponent("glyph-outlines/layer-0")
let outputDir = pipelineDir.appendingPathComponent("intermediate-blends")
let excludedBasenames: Set<String> = ["U042B_layer_0"]
let pointCount = 320

let variants: [Variant] = [
    Variant(
        name: "Circle",
        suffix: "C",
        seedURL: repoRoot.appendingPathComponent("design-assets/Blended/A/Circle/A_C_16.svg")
    ),
    Variant(
        name: "Polygon",
        suffix: "P",
        seedURL: repoRoot.appendingPathComponent("design-assets/Blended/A/Polygon/A_P_16.svg")
    ),
    Variant(
        name: "Square",
        suffix: "S",
        seedURL: repoRoot.appendingPathComponent("design-assets/Blended/A/Square/A_S_16.svg")
    ),
]

let foundationPaths = try variants.reduce(into: [String: [CGPoint]]()) { result, variant in
    let points = try resampledPoints(from: variant.seedURL, count: pointCount)
    result[variant.suffix] = points
}

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let glyphURLs = try FileManager.default.contentsOfDirectory(
    at: glyphDir,
    includingPropertiesForKeys: nil
)
.filter { $0.pathExtension == "svg" && !excludedBasenames.contains($0.deletingPathExtension().lastPathComponent) }
.sorted { $0.lastPathComponent < $1.lastPathComponent }

for glyphURL in glyphURLs {
    let basename = glyphURL.deletingPathExtension().lastPathComponent
    let glyphCode = basename.replacingOccurrences(of: "_layer_0", with: "")
    let sourceSVG = try String(contentsOf: glyphURL, encoding: .utf8)
    let character = attribute("data-character", in: sourceSVG) ?? glyphCode
    let sourcePoints = try resampledPoints(from: glyphURL, count: pointCount)

    for variant in variants {
        guard let foundation = foundationPaths[variant.suffix] else { continue }
        let alignedFoundation = align(foundation, to: sourcePoints)
        let variantDir = outputDir
            .appendingPathComponent(glyphCode)
            .appendingPathComponent(variant.name)
        try FileManager.default.createDirectory(at: variantDir, withIntermediateDirectories: true)

        for layer in 0...16 {
            let progress = CGFloat(layer) / 16
            let points = zip(sourcePoints, alignedFoundation).map { source, target in
                CGPoint(
                    x: source.x + (target.x - source.x) * progress,
                    y: source.y + (target.y - source.y) * progress
                )
            }
            let svg = svgDocument(
                glyphCode: glyphCode,
                character: character,
                variant: variant,
                layer: layer,
                points: points
            )
            let fileURL = variantDir.appendingPathComponent("\(glyphCode)_\(variant.suffix)_\(layer).svg")
            try svg.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    print("Generated blends for \(glyphCode) \(character)")
}

print("Done. Generated \(glyphURLs.count) glyphs x \(variants.count) variants x 17 layers.")

func resampledPoints(from url: URL, count: Int) throws -> [CGPoint] {
    let svg = try String(contentsOf: url, encoding: .utf8)
    let path = try firstShapePath(in: svg, url: url)
    guard !path.points.isEmpty else { throw PipelineError.emptyPath(url) }
    return resampleClosedPath(path.points, count: count)
}

func firstShapePath(in svg: String, url: URL) throws -> SVGPath {
    if let d = firstAttribute("d", element: "path", in: svg) {
        return try SVGPath(points: parsePathPoints(d))
    }
    if let points = firstAttribute("points", element: "polygon", in: svg) {
        return try SVGPath(points: parsePolygonPoints(points))
    }
    throw PipelineError.missingShape(url)
}

func firstAttribute(_ attributeName: String, element: String, in svg: String) -> String? {
    let pattern = #"<\#(element)\b[^>]*\#(attributeName)\s*=\s*\"([^\"]+)\""#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
          let match = regex.firstMatch(in: svg, range: NSRange(svg.startIndex..., in: svg)),
          match.numberOfRanges > 1,
          let range = Range(match.range(at: 1), in: svg)
    else { return nil }
    return String(svg[range])
}

func attribute(_ attributeName: String, in svg: String) -> String? {
    let pattern = #"\#(attributeName)\s*=\s*\"([^\"]+)\""#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: svg, range: NSRange(svg.startIndex..., in: svg)),
          match.numberOfRanges > 1,
          let range = Range(match.range(at: 1), in: svg)
    else { return nil }
    return String(svg[range])
}

func parsePolygonPoints(_ points: String) throws -> [CGPoint] {
    let values = numericValues(in: points)
    guard values.count >= 4, values.count.isMultiple(of: 2) else {
        throw PipelineError.malformedPath("polygon point list must contain x/y pairs")
    }
    return stride(from: 0, to: values.count, by: 2).map {
        CGPoint(x: values[$0], y: values[$0 + 1])
    }
}

func parsePathPoints(_ d: String) throws -> [CGPoint] {
    let tokens = tokenizePath(d)
    var index = 0
    var command: Character?
    var current = CGPoint.zero
    var start = CGPoint.zero
    var lastCubicControl: CGPoint?
    var points: [CGPoint] = []

    func hasNumber() -> Bool {
        guard index < tokens.count else { return false }
        if case .number = tokens[index] { return true }
        return false
    }

    func readNumber() throws -> CGFloat {
        guard index < tokens.count else { throw PipelineError.malformedPath("unexpected end of path") }
        guard case let .number(value) = tokens[index] else {
            throw PipelineError.malformedPath("expected number")
        }
        index += 1
        return value
    }

    func readPoint(relative: Bool) throws -> CGPoint {
        let x = try readNumber()
        let y = try readNumber()
        return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
    }

    while index < tokens.count {
        if case let .command(nextCommand) = tokens[index] {
            command = nextCommand
            index += 1
        }

        guard let activeCommand = command else {
            throw PipelineError.malformedPath("path must start with a command")
        }

        let relative = activeCommand.isLowercase
        switch Character(activeCommand.uppercased()) {
        case "M":
            current = try readPoint(relative: relative)
            start = current
            points.append(current)
            lastCubicControl = nil
            command = relative ? "l" : "L"
            while hasNumber() {
                current = try readPoint(relative: relative)
                points.append(current)
            }
        case "L":
            while hasNumber() {
                current = try readPoint(relative: relative)
                points.append(current)
            }
            lastCubicControl = nil
        case "H":
            while hasNumber() {
                let x = try readNumber()
                current = CGPoint(x: relative ? current.x + x : x, y: current.y)
                points.append(current)
            }
            lastCubicControl = nil
        case "V":
            while hasNumber() {
                let y = try readNumber()
                current = CGPoint(x: current.x, y: relative ? current.y + y : y)
                points.append(current)
            }
            lastCubicControl = nil
        case "C":
            while hasNumber() {
                let control1 = try readPoint(relative: relative)
                let control2 = try readPoint(relative: relative)
                let end = try readPoint(relative: relative)
                for step in 1...20 {
                    let t = CGFloat(step) / 20
                    points.append(cubicPoint(t: t, start: current, control1: control1, control2: control2, end: end))
                }
                current = end
                lastCubicControl = control2
            }
        case "S":
            while hasNumber() {
                let control1 = lastCubicControl.map {
                    CGPoint(x: current.x * 2 - $0.x, y: current.y * 2 - $0.y)
                } ?? current
                let control2 = try readPoint(relative: relative)
                let end = try readPoint(relative: relative)
                for step in 1...20 {
                    let t = CGFloat(step) / 20
                    points.append(cubicPoint(t: t, start: current, control1: control1, control2: control2, end: end))
                }
                current = end
                lastCubicControl = control2
            }
        case "Q":
            while hasNumber() {
                let control = try readPoint(relative: relative)
                let end = try readPoint(relative: relative)
                for step in 1...16 {
                    let t = CGFloat(step) / 16
                    points.append(quadPoint(t: t, start: current, control: control, end: end))
                }
                current = end
            }
            lastCubicControl = nil
        case "Z":
            current = start
            lastCubicControl = nil
        default:
            throw PipelineError.unsupportedCommand(activeCommand)
        }
    }

    return points
}

enum PathToken {
    case command(Character)
    case number(CGFloat)
}

func tokenizePath(_ d: String) -> [PathToken] {
    var tokens: [PathToken] = []
    var number = ""

    func flushNumber() {
        guard !number.isEmpty else { return }
        if let value = Double(number) {
            tokens.append(.number(CGFloat(value)))
        }
        number = ""
    }

    for scalar in d.unicodeScalars {
        let character = Character(scalar)
        if character.isLetter {
            flushNumber()
            tokens.append(.command(character))
        } else if scalar == "," || scalar == " " || scalar == "\n" || scalar == "\t" || scalar == "\r" {
            flushNumber()
        } else if scalar == "-" || scalar == "+" {
            if !number.isEmpty && !number.hasSuffix("e") && !number.hasSuffix("E") {
                flushNumber()
            }
            number.append(String(character))
        } else {
            number.append(String(character))
        }
    }

    flushNumber()
    return tokens
}

func numericValues(in string: String) -> [CGFloat] {
    let pattern = #"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    return regex.matches(in: string, range: NSRange(string.startIndex..., in: string)).compactMap { match in
        guard let range = Range(match.range, in: string),
              let value = Double(string[range])
        else { return nil }
        return CGFloat(value)
    }
}

func resampleClosedPath(_ points: [CGPoint], count: Int) -> [CGPoint] {
    guard points.count > 1 else { return points }
    let closed = points + [points[0]]
    var distances = [CGFloat](repeating: 0, count: closed.count)
    for index in 1..<closed.count {
        distances[index] = distances[index - 1] + distance(closed[index - 1], closed[index])
    }
    let totalLength = distances.last ?? 0
    guard totalLength > 0 else { return Array(repeating: points[0], count: count) }

    return (0..<count).map { sampleIndex in
        let target = totalLength * CGFloat(sampleIndex) / CGFloat(count)
        var segmentIndex = 1
        while segmentIndex < distances.count - 1, distances[segmentIndex] < target {
            segmentIndex += 1
        }
        let segmentStart = closed[segmentIndex - 1]
        let segmentEnd = closed[segmentIndex]
        let segmentLength = distances[segmentIndex] - distances[segmentIndex - 1]
        let t = segmentLength == 0 ? 0 : (target - distances[segmentIndex - 1]) / segmentLength
        return CGPoint(
            x: segmentStart.x + (segmentEnd.x - segmentStart.x) * t,
            y: segmentStart.y + (segmentEnd.y - segmentStart.y) * t
        )
    }
}

func align(_ target: [CGPoint], to source: [CGPoint]) -> [CGPoint] {
    let forward = bestRotation(of: target, to: source)
    let reversed = bestRotation(of: Array(target.reversed()), to: source)
    return squaredDistance(forward, source) <= squaredDistance(reversed, source) ? forward : reversed
}

func bestRotation(of target: [CGPoint], to source: [CGPoint]) -> [CGPoint] {
    guard target.count == source.count, !target.isEmpty else { return target }
    let strideSize = max(1, target.count / 80)
    var bestOffset = 0
    var bestDistance = CGFloat.greatestFiniteMagnitude

    for offset in stride(from: 0, to: target.count, by: strideSize) {
        let rotated = rotate(target, by: offset)
        let value = squaredDistance(rotated, source)
        if value < bestDistance {
            bestDistance = value
            bestOffset = offset
        }
    }

    let searchStart = max(0, bestOffset - strideSize)
    let searchEnd = min(target.count - 1, bestOffset + strideSize)
    for offset in searchStart...searchEnd {
        let rotated = rotate(target, by: offset)
        let value = squaredDistance(rotated, source)
        if value < bestDistance {
            bestDistance = value
            bestOffset = offset
        }
    }

    return rotate(target, by: bestOffset)
}

func rotate(_ points: [CGPoint], by offset: Int) -> [CGPoint] {
    guard !points.isEmpty else { return points }
    let normalizedOffset = ((offset % points.count) + points.count) % points.count
    return Array(points[normalizedOffset...]) + Array(points[..<normalizedOffset])
}

func squaredDistance(_ lhs: [CGPoint], _ rhs: [CGPoint]) -> CGFloat {
    zip(lhs, rhs).reduce(0) { partial, pair in
        partial + pow(pair.0.x - pair.1.x, 2) + pow(pair.0.y - pair.1.y, 2)
    }
}

func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
    hypot(lhs.x - rhs.x, lhs.y - rhs.y)
}

func quadPoint(t: CGFloat, start: CGPoint, control: CGPoint, end: CGPoint) -> CGPoint {
    let mt = 1 - t
    return CGPoint(
        x: mt * mt * start.x + 2 * mt * t * control.x + t * t * end.x,
        y: mt * mt * start.y + 2 * mt * t * control.y + t * t * end.y
    )
}

func cubicPoint(t: CGFloat, start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint) -> CGPoint {
    let mt = 1 - t
    return CGPoint(
        x: mt * mt * mt * start.x + 3 * mt * mt * t * control1.x + 3 * mt * t * t * control2.x + t * t * t * end.x,
        y: mt * mt * mt * start.y + 3 * mt * mt * t * control1.y + 3 * mt * t * t * control2.y + t * t * t * end.y
    )
}

func svgDocument(glyphCode: String, character: String, variant: Variant, layer: Int, points: [CGPoint]) -> String {
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <svg id="\(glyphCode)_\(variant.suffix)_\(layer)" data-character="\(character)" data-variant="\(variant.name)" data-layer="\(layer)" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 184 160">
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
      <path id="\(glyphCode)_\(variant.suffix)_\(layer)_outline" class="cls-1" d="\(pathData(for: points))"/>
    </svg>

    """
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

func number(_ value: CGFloat) -> String {
    let rounded = (Double(value) * 1000).rounded() / 1000
    return String(format: "%.3f", rounded)
        .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
}
