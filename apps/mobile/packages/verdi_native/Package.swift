// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VerdiNative",
    platforms: [.macOS(.v14), .iOS("18.0")],
    products: [.library(name: "VerdiNative", targets: ["VerdiNative"])],
    targets: [
        .target(name: "VerdiNative", linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "VerdiNativeTests", dependencies: ["VerdiNative"], resources: [.copy("Fixtures")]),
    ]
)
