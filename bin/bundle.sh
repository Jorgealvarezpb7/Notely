#!/usr/bin/env bash
set -euo pipefail

# Usage: bundle.sh <app> <executable>
app="${1:?usage: bundle.sh <app> <executable>}"
executable="${2:?usage: bundle.sh <app> <executable>}"

rm -rf "$app"

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

cp "$executable" "$app/Contents/MacOS/Notely"
cp Packaging/Info.plist "$app/Contents/Info.plist"
cp .build/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$app"
codesign --verify "$app"
