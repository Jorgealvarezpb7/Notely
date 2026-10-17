#!/usr/bin/env bash
set -euo pipefail

# Usage: install.sh <bundle_id> <app>
bundle_id="${1:?usage: install.sh <bundle_id> <app>}"
app="${2:?usage: install.sh <bundle_id> <app>}"

# Quit through Apple Events so Notely terminates normally and saves.
if pgrep -x Notely >/dev/null; then
    osascript -e 'tell application id "'"$bundle_id"'" to quit'
fi

# Wait for the old process to exit, or `open` would bring it forward
# instead of starting the new build.
for _ in $(seq 1 100); do
    pgrep -x Notely >/dev/null || break
    sleep 0.1
done

if pgrep -x Notely >/dev/null; then
    echo "error: Notely did not quit within 10 seconds" >&2
    exit 1
fi

mkdir -p ~/Applications

rm -rf ~/Applications/Notely.app

ditto "$app" ~/Applications/Notely.app

# Refresh the modification date so Finder and the Dock pick up the
# new icon instead of a cached one.
touch ~/Applications/Notely.app
