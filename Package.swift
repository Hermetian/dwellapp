// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Dwell",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Models",
            targets: ["Models"]),
        .library(
            name: "Services",
            targets: ["Services"]),
        .library(
            name: "ViewModels",
            targets: ["ViewModels"]),
        .library(
            name: "Views",
            targets: ["Views"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", exact: "10.19.0"),
    ],
    targets: [
        .target(
            name: "Models",
            dependencies: [
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestoreSwift", package: "firebase-ios-sdk")
            ],
            path: "Sources/Models",
            swiftSettings: [
                .define("GRPC_BUILD_FROM_SOURCE")
            ]
        ),
        .target(
            name: "Services",
            dependencies: [
                "Models",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk")
            ],
            path: "Sources/Services",
            swiftSettings: [
                .define("GRPC_BUILD_FROM_SOURCE")
            ]
        ),
        .target(
            name: "ViewModels",
            dependencies: [
                "Models",
                "Services"
            ],
            path: "Sources/ViewModels"
        ),
        .target(
            name: "Views",
            dependencies: [
                "Models",
                "Services",
                "ViewModels",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk")
            ],
            path: "Sources/Views",
            swiftSettings: [
                .define("GRPC_BUILD_FROM_SOURCE")
            ],
            linkerSettings: [
                .linkedFramework("UIKit", .when(platforms: [.iOS])),
                .linkedFramework("AppKit", .when(platforms: [.macOS]))
            ]
        ),
        .executableTarget(
            name: "App",
            dependencies: [
                "Models",
                "Services",
                "ViewModels",
                "Views"
            ],
            path: "Sources/App",
            swiftSettings: [
                .define("GRPC_BUILD_FROM_SOURCE")
            ]
        ),
        .testTarget(
            name: "DwellTests",
            dependencies: ["Views"],
            path: "Tests"
        )
    ]
)