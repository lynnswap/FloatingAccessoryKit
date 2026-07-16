// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "FloatingAccessoryKitPublicAPIClient",
    platforms: [
        .iOS("18.0")
    ],
    products: [
        .library(
            name: "FloatingAccessoryKitPublicAPIClient",
            targets: ["FloatingAccessoryKitPublicAPIClient"]
        )
    ],
    dependencies: [
        .package(path: "../../..")
    ],
    targets: [
        .target(
            name: "FloatingAccessoryKitPublicAPIClient",
            dependencies: ["FloatingAccessoryKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
