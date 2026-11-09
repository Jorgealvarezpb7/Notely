#!/usr/bin/env bash
set -euo pipefail

# Usage: build-universal.sh <app>
app="${1:?usage: build-universal.sh <app>}"

swift build -c release --arch arm64 --arch x86_64

# The output directory differs between toolchains, so ask SwiftPM for it.
executable="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Notely"

expected=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" Packaging/Info.plist)

# Compare before bundling so a binary with the wrong deployment target
# never reaches the app. vtool fails here if a slice is missing.
for arch in arm64 x86_64; do
    minos=$(vtool -arch "$arch" -show-build "$executable" | awk '$1 == "minos" { print $2 }')

    if [[ "$minos" != "$expected" ]]; then
        echo "error: $arch slice has minos '$minos' but LSMinimumSystemVersion is '$expected'" >&2
        exit 1
    fi
done

./bin/bundle.sh "$app" "$executable"
