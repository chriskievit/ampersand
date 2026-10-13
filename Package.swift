// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Ampersand",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Ampersand", targets: ["AmpersandApp"]),
        .library(name: "AmpersandCore", targets: ["AmpersandCore"]),
    ],
    targets: [
        .target(name: "AmpersandCore"),
        .executableTarget(name: "AmpersandApp", dependencies: ["AmpersandCore"]),
        .testTarget(
            name: "AmpersandCoreTests",
            dependencies: ["AmpersandCore"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
