// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeetingBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MeetingBar",
            path: "Sources/MeetingBar",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/MeetingBar/Info.plist"
                ])
            ]
        )
    ]
)
