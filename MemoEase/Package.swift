// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "MemoEase",
    platforms: [.iOS(.v15)],
    products: [
        .executable(name: "MemoEase", targets: ["MemoEase"])
    ],
    targets: [
        .executableTarget(
            name: "MemoEase",
            path: "Sources",
            resources: [.process("Resources")]
        )
    ]
)
