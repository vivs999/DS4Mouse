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
cp Resources/MenuBarIcon.png "$bundle/Contents/Resources/MenuBarIcon.png"
# A certificate-backed identity keeps privacy permissions stable across local updates.
local_identity="${DS4_LOCAL_SIGN_IDENTITY:-}"
if [[ -z "$local_identity" ]]; then
  local_identity="$(security find-identity -v -p codesigning | awk '/"Apple Development:/ { print $2; exit }')"
fi
local_identity="${local_identity:--}"
if [[ "$local_identity" == "-" ]]; then
  printf 'Warning: ad hoc signing can require privacy permission again after each update.\n' >&2
else
  printf 'Using certificate-backed local development signing.\n'
fi
codesign --force --sign "$local_identity" --identifier io.github.vivs999.DS4Mouse.cli "$bundle/Contents/MacOS/ds4mouse"
codesign --force --sign "$local_identity" --identifier io.github.vivs999.DS4Mouse "$bundle"
codesign --verify --deep --strict "$bundle"
printf 'Local development app: %s\n' "$bundle"
