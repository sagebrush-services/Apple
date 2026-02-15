// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Sagebrush",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "Dali",
            targets: ["Dali"]
        ),
        .library(
            name: "NotationEngine",
            targets: ["NotationEngine"]
        ),
    ],
    dependencies: [
        // Database
        .package(url: "https://github.com/vapor/fluent.git", from: "4.12.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.10.1"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),

        // AWS
        .package(url: "https://github.com/soto-project/soto.git", from: "7.10.0"),

        // JSON Schema validation
        .package(url: "https://github.com/ajevans99/swift-json-schema", from: "0.8.0"),

        // YAML parsing
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Sagebrush",
            dependencies: [
                "Dali",
                "NotationEngine",
            ],
            path: "Sources/Sagebrush",
            exclude: [
                "Info.plist",
                "Assets.xcassets",
            ]
        ),
        .target(
            name: "Dali",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "SotoSES", package: "soto"),
                .product(name: "SotoS3", package: "soto"),
                .product(name: "JSONSchema", package: "swift-json-schema"),
                .product(name: "Yams", package: "Yams"),
                "NotationEngine",
            ],
            path: "Sources/Dali",
            resources: [
                .copy("Seeds")
            ]
        ),
        .target(
            name: "NotationEngine",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/NotationEngine"
        ),
        .testTarget(
            name: "SagebrushTests",
            dependencies: [
                "Sagebrush",
                "Dali",
            ],
            path: "Tests/SagebrushTests"
        ),
    ]
)
