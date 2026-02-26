// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotesApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1")
    ],
    targets: [
        .executableTarget(
            name: "NotesApp",
            dependencies: [
                .product(name: "HotKey", package: "HotKey")
            ],
            path: "Sources/NotesApp"
        )
    ]
)
