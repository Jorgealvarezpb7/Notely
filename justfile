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
    ./bin/bundle.sh {{app}} .build/release/Notely

# Builds and ad-hoc signs a universal (arm64 and x86_64) Notely.app
build-universal: _icon
    ./bin/build-universal.sh {{app}}

# Builds the universal app and packages it as Notely.dmg
dmg: build-universal
    ./bin/dmg.sh {{app}}

# Tags v<version> from main and publishes Notely.dmg as a GitHub Release
release:
    ./bin/release.sh

# Replaces ~/Applications/Notely.app, quitting a running Notely first
install: build
    ./bin/install.sh {{bundle_id}} {{app}}

# Installs and opens Notely
run: install
    open ~/Applications/Notely.app
