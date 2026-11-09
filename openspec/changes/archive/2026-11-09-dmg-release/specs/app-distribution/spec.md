# Spec Delta

## Purpose

Lets people outside the author's Mac install Notely, by packaging it as a universal, ad-hoc signed DMG, publishing it to GitHub Releases from guarded local recipes, and documenting installation for end users.

## ADDED Requirements

### Requirement: Universal build
`just build-universal` SHALL produce an ad-hoc signed `Notely.app` whose executable contains both an arm64 and an x86_64 slice.

#### Scenario: Both architectures present
- **WHEN** `just build-universal` completes successfully
- **THEN** `lipo -info` on `Notely.app/Contents/MacOS/Notely` reports both `arm64` and `x86_64`

#### Scenario: Signature is valid
- **WHEN** `just build-universal` completes successfully
- **THEN** `codesign --verify Notely.app` succeeds

### Requirement: Deployment target check
`just build-universal` MUST fail, without assembling `Notely.app`, unless the `minos` of both slices equals `LSMinimumSystemVersion` in `Packaging/Info.plist`.

#### Scenario: Deployment target matches
- **GIVEN** `LSMinimumSystemVersion` is `14.0`
- **WHEN** the arm64 and x86_64 slices both report `minos 14.0`
- **THEN** the recipe continues and assembles `Notely.app`

#### Scenario: A slice does not match
- **GIVEN** `LSMinimumSystemVersion` is `14.0`
- **WHEN** either slice reports a different `minos`
- **THEN** the recipe exits non-zero, names the slice and both versions, and does not assemble `Notely.app`

### Requirement: Local builds stay native
`just build`, `just install`, and `just run` SHALL keep building for the host architecture only.

#### Scenario: Local install
- **WHEN** a developer runs `just install`
- **THEN** a single-architecture release build is installed and no universal build runs

### Requirement: DMG contents
`just dmg` SHALL build the universal app and create a DMG holding `Notely.app` and a symlink named `Applications` that points to `/Applications`.

#### Scenario: Mounted DMG
- **WHEN** a user opens the DMG created by `just dmg`
- **THEN** the volume shows `Notely.app` and an `Applications` link they can drag the app onto

### Requirement: Stable DMG name
The DMG SHALL always be written to `Notely.dmg` in the repository root, with no version in the name, replacing any earlier file.

#### Scenario: Rebuilding the DMG
- **GIVEN** `Notely.dmg` already exists
- **WHEN** `just dmg` runs again
- **THEN** `Notely.dmg` is replaced and no other DMG file is left in the repository root

#### Scenario: Git stays clean
- **WHEN** `just dmg` completes
- **THEN** `git status --porcelain` shows no new entries

### Requirement: Release version
`just release` SHALL take the version from `CFBundleShortVersionString` in `Packaging/Info.plist` and use the tag `v<version>`.

#### Scenario: Version 0.1.0
- **GIVEN** `CFBundleShortVersionString` is `0.1.0`
- **WHEN** `just release` runs
- **THEN** the tag and the GitHub Release are both named `v0.1.0`

### Requirement: Release preconditions
`just release` MUST check every precondition before building, and MUST stop with a non-zero exit and an explanatory message, without building, tagging, pushing, or publishing, when any precondition fails.

#### Scenario: Not on main
- **WHEN** `just release` runs on any branch other than `main`
- **THEN** it stops before building

#### Scenario: Dirty tree
- **WHEN** the working tree has modified, staged, or untracked files that git does not ignore
- **THEN** it stops before building

#### Scenario: Main differs from origin
- **WHEN** local `main` is behind, ahead of, or diverged from `origin/main` after fetching
- **THEN** it stops before building

#### Scenario: Tag exists locally
- **WHEN** tag `v<version>` exists in the local repository
- **THEN** it stops before building

#### Scenario: Tag exists on origin
- **WHEN** tag `v<version>` exists on `origin` but not locally
- **THEN** it stops before building

#### Scenario: Origin cannot be reached
- **WHEN** the fetch or the remote tag lookup fails
- **THEN** it stops before building

### Requirement: Release sequence
After the preconditions pass, `just release` SHALL build the DMG, create tag `v<version>`, push that tag to `origin`, and publish a GitHub Release with `Notely.dmg` attached and generated notes, in that order, stopping at the first failure.

#### Scenario: Successful release
- **WHEN** every precondition passes and every step succeeds
- **THEN** `origin` has tag `v<version>` and its GitHub Release has the asset `Notely.dmg` and generated notes

#### Scenario: Build fails
- **WHEN** the DMG build fails
- **THEN** no tag is created or pushed and no release is published

### Requirement: End-user install instructions
The README SHALL have an "Install" section that tells end users to download the DMG from GitHub Releases and drag Notely to Applications, and explains the first launch of an app that is not notarized.

#### Scenario: First launch on macOS 14
- **WHEN** a macOS 14 user reads the Install section
- **THEN** it tells them to Control-click the app and choose Open

#### Scenario: First launch on macOS 15 or later
- **WHEN** a macOS 15 or later user reads the Install section
- **THEN** it tells them to use System Settings, Privacy & Security, Open Anyway

#### Scenario: Fallback command
- **WHEN** a user cannot open the app through those steps
- **THEN** the Install section gives `xattr -dr com.apple.quarantine /Applications/Notely.app`

#### Scenario: Keychain prompt after updating
- **WHEN** a user reads the Install section
- **THEN** it notes that macOS may ask again for Keychain access to the GitHub token after an update
