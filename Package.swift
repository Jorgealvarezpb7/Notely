// swift-tools-version:5.9
import PackageDescription

// NotelyCore uses Foundation only, so it builds and tests on Linux too.
// The app targets need AppKit and exist only on macOS.
var targets: [Target] = [
    .target(name: "NotelyCore", path: "Sources/NotelyCore"),
    .testTarget(name: "NotelyCoreTests", dependencies: ["NotelyCore"], path: "Tests/NotelyCoreTests"),
]

#if os(macOS)
targets += [
    .target(name: "NotelyLinks", dependencies: ["NotelyCore"], path: "Sources/NotelyLinks"),
    .target(name: "NotelyGitHub", dependencies: ["NotelyCore"], path: "Sources/NotelyGitHub"),
    .target(name: "NotelyUI", dependencies: ["NotelyCore", "NotelyGitHub", "NotelyLinks"], path: "Sources/NotelyUI"),
    .executableTarget(name: "Notely", dependencies: ["NotelyCore", "NotelyGitHub", "NotelyLinks", "NotelyUI"],
                      path: "Sources/Notely"),
]
#endif

let package = Package(
    name: "Notely",
    platforms: [.macOS(.v14)],
    targets: targets
)
