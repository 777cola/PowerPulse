// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PowerPulse",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "PowerPulse",
            path: "PowerPulse",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("QuartzCore"),
            ]
        )
    ]
)
