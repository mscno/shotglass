// swift-tools-version: 5.10
import PackageDescription
import Foundation
let storeEdition = ProcessInfo.processInfo.environment["APP_EDITION"] == "app-store"

let package = Package(
    name: "Shotglass",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Shotglass", targets: ["Shotglass"])],
    dependencies: storeEdition ? [] : [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "ShotglassCore"),
        .executableTarget(name: "Shotglass", dependencies: [.target(name: "ShotglassCore")] + (storeEdition ? [] : [.product(name: "Sparkle", package: "Sparkle")]), linkerSettings: storeEdition ? [] : [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "ShotglassCoreTests", dependencies: ["ShotglassCore"])
    ]
)
