// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CasualContactsPackages",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "CoreModels", targets: ["CoreModels"]),
        .library(name: "Storage", targets: ["Storage"])
    ],
    targets: [
        .target(
            name: "CoreModels",
            path: "Sources/CoreModels"
        ),
        .testTarget(
            name: "CoreModelsTests",
            dependencies: ["CoreModels"],
            path: "Tests/CoreModelsTests"
        ),
        .target(
            name: "Storage",
            dependencies: ["CoreModels"],
            path: "Sources/Storage"
        ),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Storage", "CoreModels"],
            path: "Tests/StorageTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
