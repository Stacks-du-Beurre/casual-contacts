import Foundation

public enum SVGParser {

    /// Parse the `d` attribute of an SVG `<path>` element into a list of `PathCommand`s.
    /// Supports the subset we need: M, L, C, Q, Z (absolute forms only at this point).
    /// Relative forms (lowercase) and arcs (A) can be added when the assets actually use them.
    public static func parse(d: String) throws -> [PathCommand] {
        var scanner = Scanner(d.trimmingCharacters(in: .whitespacesAndNewlines))
        var commands: [PathCommand] = []

        while !scanner.isAtEnd {
            scanner.skipWhitespaceAndCommas()
            guard let command = scanner.nextChar() else { break }

            switch command {
            case "M":
                let (x, y) = try scanner.readPoint()
                commands.append(.moveTo(x: x, y: y))
            case "L":
                let (x, y) = try scanner.readPoint()
                commands.append(.lineTo(x: x, y: y))
            case "C":
                let (c1x, c1y) = try scanner.readPoint()
                let (c2x, c2y) = try scanner.readPoint()
                let (x, y) = try scanner.readPoint()
                commands.append(.cubicBezier(c1x: c1x, c1y: c1y, c2x: c2x, c2y: c2y, x: x, y: y))
            case "Q":
                let (cx, cy) = try scanner.readPoint()
                let (x, y) = try scanner.readPoint()
                commands.append(.quadraticBezier(cx: cx, cy: cy, x: x, y: y))
            case "Z", "z":
                commands.append(.closePath)
            default:
                throw SVGParserError.unknownCommand(command)
            }
        }

        return commands
    }
}

// MARK: - Scanner

private struct Scanner {
    let characters: [Character]
    var index = 0

    init(_ string: String) {
        self.characters = Array(string)
    }

    var isAtEnd: Bool { index >= characters.count }

    mutating func nextChar() -> Character? {
        guard !isAtEnd else { return nil }
        defer { index += 1 }
        return characters[index]
    }

    func peek() -> Character? {
        isAtEnd ? nil : characters[index]
    }

    mutating func skipWhitespaceAndCommas() {
        while let c = peek(), c.isWhitespace || c == "," {
            index += 1
        }
    }

    mutating func readNumber() throws -> Double {
        skipWhitespaceAndCommas()
        var buffer = ""
        // Optional leading sign
        if let c = peek(), c == "-" || c == "+" {
            buffer.append(c); index += 1
        }
        // Integer part
        while let c = peek(), c.isNumber {
            buffer.append(c); index += 1
        }
        // Decimal part
        if let c = peek(), c == "." {
            buffer.append(c); index += 1
            while let c = peek(), c.isNumber {
                buffer.append(c); index += 1
            }
        }
        guard let value = Double(buffer), !buffer.isEmpty else {
            throw SVGParserError.malformedNumber(buffer)
        }
        return value
    }

    mutating func readPoint() throws -> (x: Double, y: Double) {
        let x = try readNumber()
        // SVG points can be separated by comma, space, or implicit with a leading minus
        skipWhitespaceAndCommas()
        let y = try readNumber()
        return (x, y)
    }
}
