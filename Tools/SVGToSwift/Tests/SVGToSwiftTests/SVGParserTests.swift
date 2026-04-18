import Testing
@testable import SVGToSwift

@Suite struct SVGParserTests {

    @Test func parsesSingleMoveTo() throws {
        let commands = try SVGParser.parse(d: "M10,20")
        #expect(commands == [.moveTo(x: 10, y: 20)])
    }

    @Test func parsesMoveToAndLineTo() throws {
        let commands = try SVGParser.parse(d: "M10,20 L30,40")
        #expect(commands == [.moveTo(x: 10, y: 20), .lineTo(x: 30, y: 40)])
    }

    @Test func parsesCubicBezier() throws {
        let commands = try SVGParser.parse(d: "M0,0 C10,10 20,20 30,30")
        #expect(commands == [
            .moveTo(x: 0, y: 0),
            .cubicBezier(c1x: 10, c1y: 10, c2x: 20, c2y: 20, x: 30, y: 30)
        ])
    }

    @Test func parsesClosePath() throws {
        let commands = try SVGParser.parse(d: "M0,0 L10,0 L10,10 Z")
        #expect(commands.last == .closePath)
    }

    @Test func handlesSpaceOrCommaSeparators() throws {
        let a = try SVGParser.parse(d: "M10,20 L30,40")
        let b = try SVGParser.parse(d: "M10 20 L30 40")
        let c = try SVGParser.parse(d: "M10 20L30 40")
        #expect(a == b)
        #expect(b == c)
    }

    @Test func handlesNegativeNumbersAsSeparators() throws {
        // "-" can act as a separator when preceded by a digit
        let commands = try SVGParser.parse(d: "M10-20L-30-40")
        #expect(commands == [.moveTo(x: 10, y: -20), .lineTo(x: -30, y: -40)])
    }

    @Test func ignoresLeadingAndTrailingWhitespace() throws {
        let commands = try SVGParser.parse(d: "   M10,20   ")
        #expect(commands == [.moveTo(x: 10, y: 20)])
    }

    @Test func throwsOnMalformed() {
        #expect(throws: SVGParserError.self) {
            try SVGParser.parse(d: "Zzz nonsense")
        }
    }
}
