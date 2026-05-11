import Foundation
import SwiftUI

public extension CCVisuals.Guilloche {
    enum SVGResource {
        public enum Kind: Sendable {
            case rotation
            case blend

            public var resourceDirectory: String {
                switch self {
                case .rotation: "Guilloche/Rotation/Cyrillic"
                case .blend: "Guilloche/Blend/Cyrillic"
                }
            }
        }

        public static func paths(named name: String, kind: Kind) -> [Path] {
            let url = CCVisuals.bundle.url(
                forResource: name,
                withExtension: "svg",
                subdirectory: kind.resourceDirectory
            ) ?? CCVisuals.bundle.url(
                forResource: name,
                withExtension: "svg"
            )

            guard let url,
                  let contents = try? String(contentsOf: url, encoding: .utf8)
            else { return [] }

            return paths(in: contents)
        }

        private static func paths(in contents: String) -> [Path] {
            let shapePattern = #"<(path|polygon)\b([^>]*)>"#
            guard let regex = try? NSRegularExpression(
                pattern: shapePattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) else { return [] }

            let matches = regex.matches(in: contents, range: NSRange(contents.startIndex..., in: contents))
            return matches.compactMap { match in
                guard let elementRange = Range(match.range(at: 1), in: contents),
                      let attributesRange = Range(match.range(at: 2), in: contents)
                else { return nil }

                let element = String(contents[elementRange]).lowercased()
                let attributes = String(contents[attributesRange])

                do {
                    let commands: [PathCommand]
                    switch element {
                    case "path":
                        guard let d = attribute("d", in: attributes) else { return nil }
                        commands = try SVGParser.parse(d: d)
                    case "polygon":
                        guard let points = attribute("points", in: attributes) else { return nil }
                        commands = try SVGParser.parsePolygon(points: points)
                    default:
                        return nil
                    }
                    return Path(commands)
                } catch {
                    return nil
                }
            }
        }

        private static func attribute(_ name: String, in attributes: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern: #"(?:^|\s)\#(name)\s*=\s*"([^"]*)""#) else {
                return nil
            }
            let match = regex.firstMatch(in: attributes, range: NSRange(attributes.startIndex..., in: attributes))
            guard let match, let range = Range(match.range(at: 1), in: attributes) else {
                return nil
            }
            return String(attributes[range])
        }
    }
}

private extension Path {
    init(_ commands: [PathCommand]) {
        self.init { path in
            for command in commands {
                switch command {
                case .moveTo(let x, let y):
                    path.move(to: CGPoint(x: x, y: y))
                case .lineTo(let x, let y):
                    path.addLine(to: CGPoint(x: x, y: y))
                case .cubicBezier(let c1x, let c1y, let c2x, let c2y, let x, let y):
                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: c1x, y: c1y),
                        control2: CGPoint(x: c2x, y: c2y)
                    )
                case .quadraticBezier(let cx, let cy, let x, let y):
                    path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
                case .closePath:
                    path.closeSubpath()
                }
            }
        }
    }
}
