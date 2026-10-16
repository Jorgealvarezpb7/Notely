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
