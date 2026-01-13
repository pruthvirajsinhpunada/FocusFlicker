// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusFlicker",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "FocusFlicker",
            targets: ["FocusFlicker"]
        )
    ],
    targets: [
        .target(
            name: "FocusFlicker",
            dependencies: [],
            path: "Sources/FocusFlicker"
        )
    ]
)
