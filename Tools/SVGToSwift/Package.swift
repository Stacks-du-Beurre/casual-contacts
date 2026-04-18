// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SVGToSwift",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "svg-to-swift", targets: ["SVGToSwift"])
    ],
    targets: [
        .executableTarget(
            name: "SVGToSwift",
            path: "Sources/SVGToSwift"
        ),
        .testTarget(
            name: "SVGToSwiftTests",
            dependencies: ["SVGToSwift"],
            path: "Tests/SVGToSwiftTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
