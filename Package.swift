// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Notely",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NotelyCore", path: "Sources/NotelyCore"),
        .testTarget(name: "NotelyCoreTests", dependencies: ["NotelyCore"], path: "Tests/NotelyCoreTests"),
        .target(name: "NotelyLinks", dependencies: ["NotelyCore"], path: "Sources/NotelyLinks"),
        .target(name: "NotelyGitHub", dependencies: ["NotelyCore"], path: "Sources/NotelyGitHub"),
        .target(name: "NotelyUI", dependencies: ["NotelyCore", "NotelyGitHub", "NotelyLinks"], path: "Sources/NotelyUI"),
        .executableTarget(name: "Notely", dependencies: ["NotelyCore", "NotelyGitHub", "NotelyLinks", "NotelyUI"],
                          path: "Sources/Notely"),
    ]
)
