// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CasualContactsPackages",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "CoreModels", targets: ["CoreModels"]),
        .library(name: "Storage", targets: ["Storage"]),
        .library(name: "StorageTestSupport", targets: ["StorageTestSupport"]),
        .library(name: "Services", targets: ["Services"]),
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
        ),
        .target(
            name: "StorageTestSupport",
            dependencies: ["CoreModels"],
            path: "Sources/StorageTestSupport"
        ),
        .testTarget(
            name: "StorageTestSupportTests",
            dependencies: ["StorageTestSupport", "CoreModels"],
            path: "Tests/StorageTestSupportTests"
        ),
        .target(
            name: "Services",
            dependencies: ["CoreModels"],
            path: "Sources/Services"
        ),
        .testTarget(
            name: "ServicesTests",
            dependencies: ["Services", "CoreModels"],
            path: "Tests/ServicesTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
