set dotenv-load
set positional-arguments

app := "Notely.app"
bundle_id := "com.alvarezjorge.Notely"

# List Tasks
default:
    just --list

# Debug build, runs the bare executable without the app bundle
dev *args:
    ./bin/debug.sh {{args}}

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
_icon:
    ./bin/icon.sh

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
    ./bin/install.sh {{bundle_id}} {{app}}

# Installs and opens Notely
run: install
    open ~/Applications/Notely.app
