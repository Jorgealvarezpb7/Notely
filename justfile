set dotenv-load
set positional-arguments

app := "Notely.app"
bundle_id := "com.alvarezjorge.Notely"

# List Tasks
default:
    just --list

# Runs the Development-Kit Container
dkc:
    docker pull ghcr.io/leoborai/dkc:latest
    docker run -it --rm \
        -v $(pwd):/app \
        -w /app \
        ghcr.io/leoborai/dkc:latest

# Runs the tests
test:
    swift test

# Builds .build/AppIcon.icns from Packaging/AppIcon.png at every standard size
_icon
    #!/usr/bin/env bash
    set -euo pipefail
    iconset=.build/AppIcon.iconset
    rm -rf "$iconset"
    mkdir -p "$iconset"
    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" Packaging/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
        sips -z $((size * 2)) $((size * 2)) Packaging/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$iconset" -o .build/AppIcon.icns

# Builds and ad-hoc signs Notely.app without launching it
build: _icon
    swift build -c release
    rm -rf {{app}}
    mkdir -p {{app}}/Contents/MacOS {{app}}/Contents/Resources
    cp .build/release/Notely {{app}}/Contents/MacOS/Notely
    cp Packaging/Info.plist {{app}}/Contents/Info.plist
    cp .build/AppIcon.icns {{app}}/Contents/Resources/AppIcon.icns
    codesign --force --sign - {{app}}
    codesign --verify {{app}}

# Replaces ~/Applications/Notely.app, quitting a running Notely first
install: build
    #!/usr/bin/env bash
    set -euo pipefail
    # Quit through Apple Events so Notely terminates normally and saves.
    if pgrep -x Notely >/dev/null; then
        osascript -e 'tell application id "{{bundle_id}}" to quit'
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
    ditto {{app}} ~/Applications/Notely.app
    # Refresh the modification date so Finder and the Dock pick up the
    # new icon instead of a cached one.
    touch ~/Applications/Notely.app

# Installs and opens Notely
run: install
    open ~/Applications/Notely.app
