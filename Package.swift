// swift-tools-version:5.9
import Foundation
import PackageDescription

// The main edition needs macOS 14. `./build_app.sh --macos12` sets CLN_MACOS12 to build the
// Monterey edition from the same code (newer features fall back to older ones, see Compat.swift).
let macOS12 = ProcessInfo.processInfo.environment["CLN_MACOS12"] != nil

let package = Package(
    name: "CLN",
    platforms: [macOS12 ? .macOS(.v12) : .macOS(.v14)],
    targets: [
        .executableTarget(name: "CLN", path: "Sources/CLN")
    ]
)
