#!/usr/bin/env bash
set -euo pipefail

# Usage: dmg.sh <app>
app="${1:?usage: dmg.sh <app>}"

staging=.build/dmg

rm -rf "$staging"

mkdir -p "$staging"

ditto "$app" "$staging/Notely.app"

ln -s /Applications "$staging/Applications"

# The website links to releases/latest/download/Notely.dmg, so this name
# must never include a version.
hdiutil create -volname Notely -srcfolder "$staging" -ov -format UDZO Notely.dmg
