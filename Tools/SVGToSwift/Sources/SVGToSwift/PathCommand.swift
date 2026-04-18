import Foundation

public enum PathCommand: Equatable, Sendable {
    case moveTo(x: Double, y: Double)
    case lineTo(x: Double, y: Double)
    case cubicBezier(c1x: Double, c1y: Double, c2x: Double, c2y: Double, x: Double, y: Double)
    case quadraticBezier(cx: Double, cy: Double, x: Double, y: Double)
    case closePath
}

public enum SVGParserError: Error, Equatable {
    case unexpectedCharacter(Character)
    case unexpectedEnd
    case unknownCommand(Character)
    case malformedNumber(String)
}
