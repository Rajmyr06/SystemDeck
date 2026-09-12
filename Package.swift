// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SystemDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SystemDeck", targets: ["SystemDeck"])
    ],
    targets: [
        .executableTarget(
            name: "SystemDeck",
            path: "Sources/SystemDeck",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SystemConfiguration")
            ]
        ),
        .testTarget(
            name: "SystemDeckTests",
            dependencies: ["SystemDeck"],
            path: "Tests/SystemDeckTests"
        )
    ]
)
