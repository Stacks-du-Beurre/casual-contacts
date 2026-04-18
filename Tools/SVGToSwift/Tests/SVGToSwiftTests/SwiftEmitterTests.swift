import Testing
@testable import SVGToSwift

@Suite struct SwiftEmitterTests {

    @Test func emitsPathConstantForSimpleCommands() {
        let commands: [PathCommand] = [.moveTo(x: 0, y: 0), .lineTo(x: 10, y: 10), .closePath]
        let swift = SwiftEmitter.emit(pathCommands: commands, constantName: "sample")

        #expect(swift.contains("static let sample = Path"))
        #expect(swift.contains("path.move(to: CGPoint(x: 0.0, y: 0.0))"))
        #expect(swift.contains("path.addLine(to: CGPoint(x: 10.0, y: 10.0))"))
        #expect(swift.contains("path.closeSubpath()"))
    }

    @Test func emitsCubicBezier() {
        let commands: [PathCommand] = [
            .moveTo(x: 0, y: 0),
            .cubicBezier(c1x: 10, c1y: 10, c2x: 20, c2y: 20, x: 30, y: 30)
        ]
        let swift = SwiftEmitter.emit(pathCommands: commands, constantName: "curved")

        #expect(swift.contains("path.addCurve(to: CGPoint(x: 30.0, y: 30.0), control1: CGPoint(x: 10.0, y: 10.0), control2: CGPoint(x: 20.0, y: 20.0))"))
    }

    @Test func emitFileAppendsAllArrayListingEveryPath() {
        let paths: [(name: String, commands: [PathCommand])] = [
            (name: "path0", commands: [.moveTo(x: 0, y: 0), .closePath]),
            (name: "path1", commands: [.moveTo(x: 1, y: 1), .closePath]),
            (name: "path2", commands: [.moveTo(x: 2, y: 2), .closePath])
        ]
        let swift = SwiftEmitter.emitFile(namespace: "CCVisuals.Guilloche.Rotation.A_Rotation", paths: paths, moduleImports: [])

        #expect(swift.contains("static let all: [Path] = ["))
        #expect(swift.contains("        path0"))
        #expect(swift.contains("        path1"))
        #expect(swift.contains("        path2"))
    }

    @Test func emitFileAllArrayIsEmptyArrayWhenNoPaths() {
        let swift = SwiftEmitter.emitFile(namespace: "CCVisuals.Guilloche.Rotation.Empty", paths: [], moduleImports: [])
        #expect(swift.contains("static let all: [Path] = []"))
    }
}
