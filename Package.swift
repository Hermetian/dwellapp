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
            name: "Dwell",
            targets: ["Dwell"]),
        .executable(
            name: "DwellApp",
            targets: ["DwellApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
    ],
    targets: [
        .target(
            name: "Dwell",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
            ],
            path: "Sources/Dwell",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "DwellApp",
            dependencies: ["Dwell"],
            path: "Sources/DwellApp"
        ),
        .testTarget(
            name: "DwellTests",
            dependencies: ["Dwell"],
            path: "Tests"
        ),
    ]
)