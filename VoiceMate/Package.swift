// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "VoiceMate",
    platforms: [.iOS(.v15)],
    products: [
        .executable(name: "VoiceMate", targets: ["VoiceMate"])
    ],
    targets: [
        .executableTarget(
            name: "VoiceMate",
            path: "Sources",
            resources: [.process("Resources")]
        )
    ]
)
