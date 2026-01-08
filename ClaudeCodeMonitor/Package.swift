// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeCodeMonitor",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCodeMonitor",
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "ClaudeCodeMonitorTests",
            dependencies: ["ClaudeCodeMonitor"],
            path: "Tests/ClaudeCodeMonitorTests"
        )
    ]
)
