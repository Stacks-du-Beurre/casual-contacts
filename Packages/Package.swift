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
        .library(name: "Visuals", targets: ["Visuals"]),
        .library(name: "FeatureList", targets: ["FeatureList"]),
        .library(name: "FeatureCreate", targets: ["FeatureCreate"]),
        .library(name: "FeatureDetail", targets: ["FeatureDetail"]),
        .library(name: "FeatureSettings", targets: ["FeatureSettings"]),
        .library(name: "AppFeature", targets: ["AppFeature"])
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
            path: "Sources/Visuals",
            resources: [.process("Resources")]
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
        ),
        .target(
            name: "FeatureList",
            dependencies: ["CoreModels", "DesignSystem", "Visuals"],
            path: "Sources/FeatureList"
        ),
        .testTarget(
            name: "FeatureListTests",
            dependencies: ["FeatureList", "CoreModels", "StorageTestSupport", "ServicesTestSupport"],
            path: "Tests/FeatureListTests"
        ),
        .target(
            name: "FeatureCreate",
            dependencies: ["CoreModels", "DesignSystem", "Visuals"],
            path: "Sources/FeatureCreate"
        ),
        .testTarget(
            name: "FeatureCreateTests",
            dependencies: ["FeatureCreate", "CoreModels"],
            path: "Tests/FeatureCreateTests"
        ),
        .target(
            name: "FeatureDetail",
            dependencies: ["CoreModels", "DesignSystem", "Visuals"],
            path: "Sources/FeatureDetail"
        ),
        .testTarget(
            name: "FeatureDetailTests",
            dependencies: ["FeatureDetail", "CoreModels", "Visuals"],
            path: "Tests/FeatureDetailTests"
        ),
        .target(
            name: "FeatureSettings",
            dependencies: ["CoreModels", "DesignSystem"],
            path: "Sources/FeatureSettings"
        ),
        .testTarget(
            name: "FeatureSettingsTests",
            dependencies: ["FeatureSettings"],
            path: "Tests/FeatureSettingsTests"
        ),
        .target(
            name: "AppFeature",
            dependencies: [
                "CoreModels",
                "Storage",
                "Services",
                "DesignSystem",
                "Visuals",
                "FeatureList",
                "FeatureCreate",
                "FeatureDetail",
                "FeatureSettings"
            ],
            path: "Sources/AppFeature"
        ),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: [
                "AppFeature",
                "CoreModels",
                "Visuals",
                "StorageTestSupport",
                "ServicesTestSupport"
            ],
            path: "Tests/AppFeatureTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
