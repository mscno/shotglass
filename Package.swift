// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Shotglass",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Shotglass", targets: ["Shotglass"])],
    targets: [
        .target(name: "ShotglassCore"),
        .executableTarget(name: "Shotglass", dependencies: ["ShotglassCore"]),
        .testTarget(name: "ShotglassCoreTests", dependencies: ["ShotglassCore"])
    ]
)
