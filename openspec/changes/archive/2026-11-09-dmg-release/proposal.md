# Proposal

## Why

Notely can only be installed by building it from source, so nobody outside the author's Mac can use it. A downloadable DMG on GitHub Releases, produced by repeatable local recipes, makes it installable on both Apple Silicon and Intel Macs. There is no Apple Developer account, so the app stays ad-hoc signed and users need instructions for getting past Gatekeeper.

## What Changes

- Add a `build-universal` recipe that builds a release binary for arm64 and x86_64 with SwiftPM's native multi-architecture build, locates it with `--show-bin-path`, fails unless both slices have a `minos` matching `LSMinimumSystemVersion`, and assembles the ad-hoc signed `Notely.app`.
- Keep `just build`, `just install`, and `just run` native and fast. Their behavior does not change.
- Add a `just dmg` recipe that depends on `build-universal` and creates `Notely.dmg`, always with that exact name, containing `Notely.app` and an `/Applications` symlink.
- Add a `just release` recipe that reads the version from `Packaging/Info.plist`, refuses to run off `main`, with a dirty tree, when `main` differs from `origin/main`, or when tag `v<version>` exists locally or on `origin`, then builds the DMG, creates and pushes the tag, and runs `gh release create v<version> Notely.dmg --generate-notes`.
- Ignore `Notely.dmg` in git. DMG staging happens in `.build/dmg`, which is already ignored.
- Add an end-user "Install" section to the README covering the DMG, first launch on macOS 14 and macOS 15+, the `xattr` fallback, and possible repeat Keychain prompts after updating.

No app code changes. CI, Developer ID signing, and notarization are out of scope.

## Capabilities

### New Capabilities

- `app-distribution`: Packaging Notely as a universal, ad-hoc signed DMG, publishing it as a GitHub Release from guarded local recipes, and documenting installation for end users.

### Modified Capabilities

None.

## Impact

- `justfile`: new `build-universal`, `dmg`, and `release` recipes; `build` delegates bundle assembly to a shared script.
- `bin/`: new `bundle.sh`, `build-universal.sh`, `dmg.sh`, and `release.sh`.
- `.gitignore` and `README.md`.
- Depends on macOS host tools: `swift`, `lipo`, `vtool`, `codesign`, `hdiutil`, `PlistBuddy`, and an authenticated `gh`.
- The website's `releases/latest/download/Notely.dmg` link relies on the exact asset name and on the repository being public.
