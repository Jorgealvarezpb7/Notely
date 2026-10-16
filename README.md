<p align="center">
  <img src="Packaging/AppIcon.png" alt="Notely logo" width="128">
</p>

<h1 align="center">Notely</h1>

<p align="center">Sticky notes for macOS, with checklists, Markdown descriptions, and GitHub issue sync.</p>

## Features

- Floating note windows that keep their text, size, and position between launches
- Bold, italic, and underline; per-note tint; text appearance settings
- Checklists and links with preview cards
- A menu window to browse, create, and open notes
- Sync notes with GitHub issues, with the token kept in the login Keychain

## Requirements

- macOS 14 or later
- Swift 5.9 toolchain (full Xcode for running tests)
- [`just`](https://github.com/casey/just)

## Build and run

```sh
just test      # run the test suite
just build     # build and ad-hoc sign Notely.app
just install   # replace ~/Applications/Notely.app
just run       # install and open
```

## Development

`just dev` builds a debug binary and runs it straight from `.build`, without the app bundle. With only the Command Line Tools installed (no Xcode), the newest SDK can fail to compile `@State` with `plugin for module 'SwiftUIMacros' not found`. Build against the older SDK instead:

```sh
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk just dev
```

## Project layout

| Target | Role |
| --- | --- |
| `NotelyCore` | Note model, store, persistence, sync rules, Markdown parser |
| `NotelyGitHub` | GitHub client and Keychain token store |
| `NotelyLinks` | Link detection and page previews |
| `NotelySQLite` | SQLite database, migrations, and note storage |
| `NotelyUI` | AppKit windows and SwiftUI views |
| `Notely` | App entry point |

Features are specified with [OpenSpec](openspec/specs).
