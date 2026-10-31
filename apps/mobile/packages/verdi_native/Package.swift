// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VerdiNative",
    platforms: [.macOS(.v14), .iOS("18.0")],
    products: [.library(name: "VerdiNative", targets: ["VerdiNative"])],
    dependencies: [.package(url: "https://github.com/weichsel/ZIPFoundation.git", revision: "22787ffb59de99e5dc1fbfe80b19c97a904ad48d")],
    targets: [
        .target(name: "VerdiNative", dependencies: [.product(name: "ZIPFoundation", package: "ZIPFoundation")], linkerSettings: [.linkedLibrary("sqlite3")]),
        .testTarget(name: "VerdiNativeTests", dependencies: ["VerdiNative"], resources: [.copy("Fixtures")]),
    ]
)
