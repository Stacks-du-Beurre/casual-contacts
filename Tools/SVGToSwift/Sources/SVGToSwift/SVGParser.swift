import Foundation

public enum SVGParser {

    /// Parse the `d` attribute of an SVG `<path>` element into a list of `PathCommand`s.
    /// Supports M/m, L/l, H/h, V/v, C/c, S/s, Q/q, Z/z — including implicit command
    /// repetition after a command letter (per SVG spec: subsequent coordinate sets
    /// reuse the last command, with `M`/`m` implicitly repeating as `L`/`l`).
    /// Smooth cubics (S/s) reflect the previous cubic's second control point.
    /// Arcs (A/a) and smooth quadratics (T/t) are not yet supported — add them
    /// when the designer's assets start using them.
    public static func parse(d: String) throws -> [PathCommand] {
        var scanner = Scanner(d.trimmingCharacters(in: .whitespacesAndNewlines))
        var commands: [PathCommand] = []

        // Track "current point" for relative commands and implicit moveTo-as-lineTo.
        var currentX: Double = 0
        var currentY: Double = 0
        // Start of the current subpath, restored by Z/z.
        var subpathStartX: Double = 0
        var subpathStartY: Double = 0
        // Last cubic bezier's second control point — used for S/s reflection.
        // Nil when the previous command wasn't a cubic; in that case the
        // reflected point is the current point.
        var lastCubicC2: (x: Double, y: Double)?

        // Last command letter seen — used to resolve implicit repetition.
        var lastCommand: Character?

        while !scanner.isAtEnd {
            scanner.skipWhitespaceAndCommas()
            if scanner.isAtEnd { break }

            // If the next character is a command letter, consume it and use it.
            // Otherwise fall back to implicit repetition of the previous command
            // (M → L, m → l, every other command → itself).
            let command: Character
            if let next = scanner.peek(), next.isLetter {
                command = scanner.nextChar()!
                lastCommand = command
            } else {
                guard let last = lastCommand else {
                    // No command yet and no command letter — malformed.
                    throw SVGParserError.unexpectedEnd
                }
                switch last {
                case "M": command = "L"
                case "m": command = "l"
                default: command = last
                }
            }

            switch command {
            case "M":
                let (x, y) = try scanner.readPoint()
                commands.append(.moveTo(x: x, y: y))
                currentX = x; currentY = y
                subpathStartX = x; subpathStartY = y
                lastCubicC2 = nil
            case "m":
                let (dx, dy) = try scanner.readPoint()
                let x = currentX + dx
                let y = currentY + dy
                commands.append(.moveTo(x: x, y: y))
                currentX = x; currentY = y
                subpathStartX = x; subpathStartY = y
                lastCubicC2 = nil
            case "L":
                let (x, y) = try scanner.readPoint()
                commands.append(.lineTo(x: x, y: y))
                currentX = x; currentY = y
                lastCubicC2 = nil
            case "l":
                let (dx, dy) = try scanner.readPoint()
                let x = currentX + dx
                let y = currentY + dy
                commands.append(.lineTo(x: x, y: y))
                currentX = x; currentY = y
                lastCubicC2 = nil
            case "H":
                let x = try scanner.readNumber()
                commands.append(.lineTo(x: x, y: currentY))
                currentX = x
                lastCubicC2 = nil
            case "h":
                let dx = try scanner.readNumber()
                let x = currentX + dx
                commands.append(.lineTo(x: x, y: currentY))
                currentX = x
                lastCubicC2 = nil
            case "V":
                let y = try scanner.readNumber()
                commands.append(.lineTo(x: currentX, y: y))
                currentY = y
                lastCubicC2 = nil
            case "v":
                let dy = try scanner.readNumber()
                let y = currentY + dy
                commands.append(.lineTo(x: currentX, y: y))
                currentY = y
                lastCubicC2 = nil
            case "C":
                let (c1x, c1y) = try scanner.readPoint()
                let (c2x, c2y) = try scanner.readPoint()
                let (x, y) = try scanner.readPoint()
                commands.append(.cubicBezier(c1x: c1x, c1y: c1y, c2x: c2x, c2y: c2y, x: x, y: y))
                currentX = x; currentY = y
                lastCubicC2 = (c2x, c2y)
            case "c":
                let (dc1x, dc1y) = try scanner.readPoint()
                let (dc2x, dc2y) = try scanner.readPoint()
                let (dx, dy) = try scanner.readPoint()
                let c1x = currentX + dc1x
                let c1y = currentY + dc1y
                let c2x = currentX + dc2x
                let c2y = currentY + dc2y
                let x = currentX + dx
                let y = currentY + dy
                commands.append(.cubicBezier(c1x: c1x, c1y: c1y, c2x: c2x, c2y: c2y, x: x, y: y))
                currentX = x; currentY = y
                lastCubicC2 = (c2x, c2y)
            case "S":
                // Smooth cubic bezier — first control is reflection of previous cubic's c2.
                let (c2x, c2y) = try scanner.readPoint()
                let (x, y) = try scanner.readPoint()
                let c1x: Double
                let c1y: Double
                if let last = lastCubicC2 {
                    c1x = 2 * currentX - last.x
                    c1y = 2 * currentY - last.y
                } else {
                    c1x = currentX; c1y = currentY
                }
                commands.append(.cubicBezier(c1x: c1x, c1y: c1y, c2x: c2x, c2y: c2y, x: x, y: y))
                currentX = x; currentY = y
                lastCubicC2 = (c2x, c2y)
            case "s":
                let (dc2x, dc2y) = try scanner.readPoint()
                let (dx, dy) = try scanner.readPoint()
                let c2x = currentX + dc2x
                let c2y = currentY + dc2y
                let x = currentX + dx
                let y = currentY + dy
                let c1x: Double
                let c1y: Double
                if let last = lastCubicC2 {
                    c1x = 2 * currentX - last.x
                    c1y = 2 * currentY - last.y
                } else {
                    c1x = currentX; c1y = currentY
                }
                commands.append(.cubicBezier(c1x: c1x, c1y: c1y, c2x: c2x, c2y: c2y, x: x, y: y))
                currentX = x; currentY = y
                lastCubicC2 = (c2x, c2y)
            case "Q":
                let (cx, cy) = try scanner.readPoint()
                let (x, y) = try scanner.readPoint()
                commands.append(.quadraticBezier(cx: cx, cy: cy, x: x, y: y))
                currentX = x; currentY = y
                lastCubicC2 = nil
            case "q":
                let (dcx, dcy) = try scanner.readPoint()
                let (dx, dy) = try scanner.readPoint()
                let cx = currentX + dcx
                let cy = currentY + dcy
                let x = currentX + dx
                let y = currentY + dy
                commands.append(.quadraticBezier(cx: cx, cy: cy, x: x, y: y))
                currentX = x; currentY = y
                lastCubicC2 = nil
            case "Z", "z":
                commands.append(.closePath)
                currentX = subpathStartX
                currentY = subpathStartY
                lastCubicC2 = nil
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
        // Optional exponent (e.g. 1.5e-3)
        if let c = peek(), c == "e" || c == "E" {
            buffer.append(c); index += 1
            if let s = peek(), s == "+" || s == "-" {
                buffer.append(s); index += 1
            }
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
