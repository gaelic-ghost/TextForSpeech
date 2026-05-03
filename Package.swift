// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TextForSpeech",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "TextForSpeech",
            targets: ["TextForSpeech"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.3"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.13.4"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "TextForSpeech",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ],
        ),
        .testTarget(
            name: "TextForSpeechTests",
            dependencies: ["TextForSpeech"],
        ),
    ],
    swiftLanguageModes: [.v6],
)
