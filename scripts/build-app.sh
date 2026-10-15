#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
bundle="$project_root/dist/DS4Mouse.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$binary_dir/DS4MouseApp" "$bundle/Contents/MacOS/DS4MouseApp"
cp "$binary_dir/ds4mouse" "$bundle/Contents/MacOS/ds4mouse"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
cp Resources/AppIcon.icns "$bundle/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier io.github.vivs999.DS4Mouse.cli "$bundle/Contents/MacOS/ds4mouse"
codesign --force --sign - --identifier io.github.vivs999.DS4Mouse "$bundle"
codesign --verify --deep --strict "$bundle"
printf 'Local development app: %s\n' "$bundle"
