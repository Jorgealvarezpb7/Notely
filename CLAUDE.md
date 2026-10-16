# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Notely: native macOS sticky-notes app (AppKit + SwiftUI, Swift 5.9 package, macOS 14+). Development often happens in a Linux container (`just dkc`) that has no Swift toolchain, AppKit, or `codesign`; build, test, and run on the macOS host.

## Commands (`just`)

- `just test` — `swift test` (Swift Testing, needs full Xcode selected via `xcode-select`)
- Single test: `swift test --filter NotelyCoreTests.FitTests` (or a test name)
- `just build` — release build, builds `.icns` from `Packaging/AppIcon.png`, assembles and ad-hoc signs `Notely.app`
- `just install` — quits running Notely, replaces `~/Applications/Notely.app`
- `just run` — install and open

No linter is configured.

## Architecture

Four library targets plus a thin executable, wired in `Package.swift`:

- `NotelyCore` — all logic and state, no AppKit/UI. `NoteStore` (`@Observable`) holds every note and every mutation rule, and saves through the `NoteRepository` protocol after each change (`UserDefaultsNoteRepository` stores one JSON array under key `notes`, with legacy single-note migration). Also: window frame math (`Geometry/Frames.swift`), `IssueSync` merge rules, `GitHubAccount` and the `TokenStore` / `IssueService` protocols, Markdown block parser, `PageHead` parser, link page key normalization. Tests live in `NotelyCoreTests` and use fakes (`FakeIssueService`) rather than network or Keychain.
- `NotelyGitHub` — concrete `GitHubClient` (URLSession) and `KeychainTokenStore` (Security framework; token cached in memory per launch to avoid repeated Keychain password prompts).
- `NotelyLinks` — `LinkDetector` (`NSDataDetector`) and link page fetching.
- `NotelyUI` — AppKit window controllers (one per note/list, menu, settings), SwiftUI views, text editor/appearance, GitHub controls.
- `Notely` (`Sources/Notely/main.swift`) — composition root; builds the store, `GitHubClient`, `KeychainTokenStore`, etc. once and passes them to `NotelyApp.run`.

Rule: protocols and pure logic go in `NotelyCore` so they stay testable; platform APIs go in the other targets.

Saved window frames are stored as `NSStringFromPoint`/`NSStringFromSize` strings; `parsePair` parses them with an explicit non-lossy fallback, so use it instead of `NSPointFromString`.

## Specs

Changes are planned with OpenSpec: `openspec/specs/` holds current capability specs, `openspec/changes/` active changes, `openspec/changes/archive/` finished ones. Slash commands `/opsx:*` and the `openspec-*` skills drive the workflow.
