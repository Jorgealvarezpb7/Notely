#!/usr/bin/env bash
set -euo pipefail

# Debug build run straight from .build, skipping the app bundle, icon
# and codesign steps. Extra arguments are passed to the executable.
swift build
exec .build/debug/Notely "$@"
