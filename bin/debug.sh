#!/usr/bin/env bash
set -euo pipefail

# Debug build run straight from .build, skipping the app bundle, icon
# and codesign steps. Extra arguments are passed to the executable.
# Debug level logs go to this terminal; override with NOTELY_LOG_LEVEL.
export NOTELY_LOG_LEVEL="${NOTELY_LOG_LEVEL:-debug}"

swift build
exec .build/debug/Notely "$@"
