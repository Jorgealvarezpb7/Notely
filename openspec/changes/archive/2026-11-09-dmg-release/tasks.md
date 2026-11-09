# Tasks

The editing container has no macOS tools. Group 1 to 4 tasks are verified statically where a check says so. Group 5 runs on the macOS host.

## 1. Universal build

- [x] 1.1 Add `bin/bundle.sh <app> <executable>` with the assembly and ad-hoc signing steps now inline in the `build` recipe, make it executable, and verify with `bash -n` and `test -x`
- [x] 1.2 Change the `build` recipe to run `swift build -c release` and then `./bin/bundle.sh {{app}} .build/release/Notely`, and verify by reading the justfile that `install` and `run` still depend on `build`
- [x] 1.3 Add `bin/build-universal.sh <app>` that builds for arm64 and x86_64, finds the binary with `--show-bin-path`, fails with `error: ...` unless each slice's `minos` from `vtool` equals `LSMinimumSystemVersion`, then calls `bin/bundle.sh`, and verify with `bash -n` and `test -x`
- [x] 1.4 Add a `build-universal` recipe depending on `_icon` with a descriptive comment like the existing recipes, and verify it is defined in the justfile

## 2. DMG

- [x] 2.1 Add `bin/dmg.sh <app>` that recreates `.build/dmg`, copies the app with `ditto`, adds the `Applications` symlink to `/Applications`, and creates `Notely.dmg` with `hdiutil`, and verify with `bash -n` and `test -x`
- [x] 2.2 Add a `dmg` recipe depending on `build-universal`, and verify it is defined in the justfile
- [x] 2.3 Add `Notely.dmg` to `.gitignore` and verify with `git check-ignore Notely.dmg`

## 3. Release

- [x] 3.1 Add `bin/release.sh` that reads the version with `PlistBuddy` and refuses, before building, when not on `main`, when `git status --porcelain` is non-empty, when `HEAD` differs from `origin/main` after `git fetch origin main`, or when the tag exists locally or on `origin`, and verify with `bash -n` and `test -x`
- [x] 3.2 Extend `bin/release.sh` to run `just dmg`, `git tag`, `git push origin <tag>`, and `gh release create v<version> Notely.dmg --generate-notes` in that order, printing the manual `gh release create` command if that last step fails, and verify the order by reading the script
- [x] 3.3 Add a `release` recipe with no dependency on `dmg`, and verify it is defined in the justfile

## 4. Documentation

- [x] 4.1 Add an "Install" section to `README.md` after "Features" covering the DMG download, dragging to Applications, Control-click and Open on macOS 14, Open Anyway on macOS 15+, the `xattr -dr com.apple.quarantine /Applications/Notely.app` fallback, and repeat Keychain prompts after updating, and verify each item appears

## 5. Host verification (macOS only, no push and no release)

- [x] 5.1 Run `just build` and verify `lipo -info Notely.app/Contents/MacOS/Notely` shows only the host architecture and `codesign --verify Notely.app` succeeds
- [x] 5.2 Run `just build-universal` and verify `lipo -info Notely.app/Contents/MacOS/Notely` shows `x86_64 arm64` and `codesign --verify Notely.app` succeeds
- [x] 5.3 Run `just dmg`, mount `Notely.dmg`, verify it holds `Notely.app` and an `Applications` link, and verify `git status --porcelain` does not list `Notely.dmg`
- [x] 5.4 Run `just release` from a non-`main` branch and verify it stops with an error before building, without creating a tag

## Workflow follow-up

- The first release is run by hand on the macOS host, from an up-to-date `main`, after this change is merged.
- Download the first release's DMG in a browser and confirm the Gatekeeper steps in the README match what macOS shows.
- Archive the change after review.
