// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeskShot",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DeskShotKit"),
        .executableTarget(name: "DeskShot", dependencies: ["DeskShotKit"]),
        .testTarget(name: "DeskShotKitTests", dependencies: ["DeskShotKit"]),
    ]
)
