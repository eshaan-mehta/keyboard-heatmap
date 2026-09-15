// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeyHeat",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "KeyHeat",
            path: "Sources/KeyHeat",
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("Charts"),
                .linkedFramework("ServiceManagement"),
                .linkedLibrary("sqlite3"),
            ]
        ),
    ]
)
