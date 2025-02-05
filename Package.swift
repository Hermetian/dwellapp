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
            path: "Sources/Models"
        ),
        .target(
            name: "Services",
            dependencies: [
                "Models",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk")
            ],
            path: "Sources/Services"
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
            path: "Sources/App"
        ),
        .testTarget(
            name: "DwellTests",
            dependencies: ["Views"],
            path: "Tests"
        )
    ]
)