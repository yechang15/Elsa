// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "PodcastApp",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "PodcastApp",
            targets: ["PodcastApp"]
        )
    ],
    dependencies: [
        // RSS解析
        .package(url: "https://github.com/nmdias/FeedKit.git", from: "9.1.2"),
        // OpenAI API客户端
        .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.2.4"),
    ],
    targets: [
        .executableTarget(
            name: "PodcastApp",
            dependencies: [
                "FeedKit",
                .product(name: "OpenAI", package: "OpenAI"),
            ],
            path: "PodcastApp"
        )
    ]
)
