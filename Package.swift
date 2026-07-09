// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VideoLyrics",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../LyrixLib"),
    ],
    targets: [
        .executableTarget(
            name: "VideoLyrics",
            dependencies: [
                .product(name: "LyrixLib", package: "LyrixLib"),
            ]
        ),
        .testTarget(
            name: "VideoLyricsTests",
            dependencies: ["VideoLyrics"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
