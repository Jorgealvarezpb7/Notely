# Design

## Context

See proposal.md for motivation and specs/app-distribution/spec.md for required behavior.

Today `just build` runs `swift build -c release`, assembles `Notely.app` inline in the justfile, and ad-hoc signs it. `bin/` holds small Bash scripts that start with `#!/usr/bin/env bash` and `set -euo pipefail`, take arguments from the justfile, and report errors as `error: ...` on stderr.

A probe on the macOS host, with only the Command Line Tools installed, showed:

- `swift build -c release --arch arm64 --arch x86_64` succeeds.
- The binary lands in `.build/out/Products/Release/Notely`, and `lipo -info` reports `x86_64 arm64`.
- `vtool` reports `minos 14.0` for both slices. The build's warning that x86_64 is deprecated for deployment target macOS 27.0 does not reflect the real target.

The editing container has no Swift or macOS tools, so every script can only be run on the host.

## Goals / Non-Goals

**Goals:**

- One command each for a distributable DMG and a guarded release.
- No published release can come from an unmerged, unpushed, or uncommitted state.

**Non-Goals:**

- A styled DMG window (background image, icon positions).
- Changing the version automatically. The version is edited by hand in `Packaging/Info.plist`.
- Rolling back a partly finished release automatically.

## Decisions

### Separate `build-universal` recipe

`build` stays native, so `just run` and `just install` keep their speed, and `dmg` depends on `build-universal`. The alternative of making `build` universal would slow every local install for a benefit only releases need.

### Native multi-architecture build, path from `--show-bin-path`

`bin/build-universal.sh` uses SwiftPM's multi-architecture build and asks `--show-bin-path` for the output directory. The path differs by toolchain (`.build/out/...` here, `.build/apple/...` elsewhere), so hardcoding it would be fragile. A separate per-architecture build merged with `lipo` is unnecessary because the native build works.

### Shared bundle assembly

Move the inline assembly steps from the `build` recipe into `bin/bundle.sh <app> <executable>`, called by both `build` and `build-universal`. Duplicating them would let the two bundles drift. The `build` recipe's result does not change.

### `minos` check before assembly

`bin/build-universal.sh` reads `LSMinimumSystemVersion` with `PlistBuddy`, then runs `vtool -arch <arch> -show-build` for arm64 and x86_64 and compares each `minos` as an exact string. It runs before `bin/bundle.sh`, so a binary with the wrong target never gets bundled. The compiler warning mentioning macOS 27.0 makes an explicit check worth having. A missing slice also fails here, because `vtool` exits non-zero and `pipefail` carries that through.

### DMG staging in `.build/dmg`

`bin/dmg.sh <app>` recreates `.build/dmg`, copies the app with `ditto` as `bin/install.sh` does, adds the `Applications` symlink, and runs `hdiutil create` with `-volname Notely -srcfolder .build/dmg -ov -format UDZO`. `.build/` is already ignored, so `.gitignore` gains only `Notely.dmg`.

### `release` runs checks inside a script, then calls `just dmg`

`release` has no just dependency on `dmg`, because just runs dependencies first and a long build would precede the checks. `bin/release.sh` performs these steps in order:

```
read version --> on main? --> tree clean? --> fetch, HEAD == origin/main?
  --> tag free locally? --> tag free on origin?
  --> just dmg --> git tag --> git push origin <tag> --> gh release create
```

Building before tagging means a failed build leaves no orphan tag.

"Up to date" means `HEAD` equals `origin/main` exactly. Being ahead is refused as well as being behind, because a tag on an unpushed commit would publish code that is not on `main`.

Cleanliness uses `git status --porcelain`, so untracked files count as dirty and ignored files, including `Notely.dmg` and `Notely.app`, do not.

The remote tag lookup captures the output of `git ls-remote --tags origin refs/tags/<tag>` and refuses on non-empty output. With `set -e`, a network failure stops the script instead of reading as "tag is free".

## Risks / Trade-offs

- [`gh release create` fails after the tag is pushed, and a rerun is refused because the tag exists] → Rerun `gh release create v<version> Notely.dmg --generate-notes` by hand. The script prints this command when that step fails.
- [Ad-hoc signing changes the app's identity on each build, so macOS may repeat Keychain prompts after an update] → Documented in the README. Only a Developer ID would remove it.
- [Gatekeeper's wording for an ad-hoc signed, quarantined app is unconfirmed] → Test a browser download on first release and adjust the README if the message differs.
- [Command Line Tools' default SDK can fail with `plugin for module 'SwiftUIMacros' not found`] → Export `SDKROOT` before `just dmg` or `just release`, as `just dev` already requires. The recipes inherit the environment and do not hardcode a machine-specific SDK path.
- [x86_64 is deprecated for newer deployment targets and may stop building in a future SDK] → Accepted for now. The build failure would be visible, and `minos` is checked.
