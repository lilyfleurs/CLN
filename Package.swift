// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CLN",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "CLN", path: "Sources/CLN")
    ]
)
