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
        .library(name: "ServicesTestSupport", targets: ["ServicesTestSupport"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Visuals", targets: ["Visuals"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0")
    ],
    targets: [
        .target(name: "CoreModels", path: "Sources/CoreModels"),
        .testTarget(name: "CoreModelsTests", dependencies: ["CoreModels"], path: "Tests/CoreModelsTests"),
        .target(name: "Storage", dependencies: ["CoreModels"], path: "Sources/Storage"),
        .testTarget(name: "StorageTests", dependencies: ["Storage", "CoreModels"], path: "Tests/StorageTests"),
        .target(name: "StorageTestSupport", dependencies: ["CoreModels"], path: "Sources/StorageTestSupport"),
        .testTarget(name: "StorageTestSupportTests", dependencies: ["StorageTestSupport", "CoreModels"], path: "Tests/StorageTestSupportTests"),
        .target(name: "Services", dependencies: ["CoreModels"], path: "Sources/Services"),
        .testTarget(name: "ServicesTests", dependencies: ["Services", "CoreModels"], path: "Tests/ServicesTests"),
        .target(name: "ServicesTestSupport", dependencies: ["CoreModels"], path: "Sources/ServicesTestSupport"),
        .testTarget(name: "ServicesTestSupportTests", dependencies: ["ServicesTestSupport", "CoreModels"], path: "Tests/ServicesTestSupportTests"),
        .target(
            name: "DesignSystem",
            path: "Sources/DesignSystem",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"], path: "Tests/DesignSystemTests"),
        .target(
            name: "Visuals",
            dependencies: [
                "CoreModels",
                "DesignSystem"
            ],
            path: "Sources/Visuals"
        ),
        .testTarget(
            name: "VisualsTests",
            dependencies: [
                "Visuals",
                "CoreModels",
                "DesignSystem",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests/VisualsTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
