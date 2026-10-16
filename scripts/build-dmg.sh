#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:---development}"
case "$mode" in
  --development) suffix="-preview.1"; volume="DS4Mouse Preview" ;;
  --release) suffix=""; volume="DS4Mouse" ;;
  *) printf 'Usage: %s [--development|--release]\n' "$0" >&2; exit 2 ;;
esac
bundle="$PWD/dist/DS4Mouse.app"
[[ -d "$bundle" ]] || { printf 'Build dist/DS4Mouse.app first.\n' >&2; exit 1; }
codesign --verify --deep --strict "$bundle"
if [[ "$mode" == "--release" ]]; then
  codesign -dv "$bundle" 2>&1 | /usr/bin/grep '^Authority=Developer ID Application:' >/dev/null
  xcrun stapler validate "$bundle"
  spctl --assess --type execute "$bundle"
else
  # Public previews must not carry a personal Apple Development certificate.
  codesign -dv "$bundle" 2>&1 | /usr/bin/grep '^Signature=adhoc$' >/dev/null || {
    printf 'Preview packaging requires an ad hoc build: DS4_LOCAL_SIGN_IDENTITY=- ./scripts/build-app.sh\n' >&2
    exit 1
  }
fi
version="$(plutil -extract CFBundleShortVersionString raw -o - "$bundle/Contents/Info.plist")"
architectures="$(lipo -archs "$bundle/Contents/MacOS/DS4MouseApp")"
cli_architectures="$(lipo -archs "$bundle/Contents/MacOS/ds4mouse")"
[[ "$architectures" == "$cli_architectures" ]] || { printf 'App and CLI architectures differ.\n' >&2; exit 1; }
case "$architectures" in
  arm64) architecture="arm64" ;;
  x86_64) architecture="x86_64" ;;
  'x86_64 arm64'|'arm64 x86_64') architecture="universal" ;;
  *) printf 'Unsupported architecture set: %s\n' "$architectures" >&2; exit 1 ;;
esac
filename="DS4Mouse-${version}${suffix}-macos-${architecture}.dmg"
[[ ! -e "dist/$filename" ]] || { printf 'Refusing to overwrite dist/%s\n' "$filename" >&2; exit 1; }
staging="$(mktemp -d "$PWD/dist/dmg-stage.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
chmod 755 "$staging"
ditto "$bundle" "$staging/DS4Mouse.app"
ln -s /Applications "$staging/Applications"
cp LICENSE "$staging/LICENSE.txt"
cat > "$staging/Read Me.txt" <<'TEXT'
DS4Mouse

1. Quit any existing DS4Mouse copy. Drag DS4Mouse.app into Applications.
   Keep only one installed copy to avoid confusion about permissions.
2. Pair your DualShock 4 over Bluetooth (hold SHARE + PS until flashing).
3. Open DS4Mouse and choose Settings from its controller menu bar icon.
4. Grant mouse control using the General permission button, then enable it.
   macOS 27 calls this Device Control and Data Access; earlier versions call
   it Accessibility. Quit and reopen after granting if needed.

The CLI is bundled at:
/Applications/DS4Mouse.app/Contents/MacOS/ds4mouse

Help, source, compatibility, and issue reports:
https://github.com/vivs999/DS4Mouse

Tested with a Bluetooth DualShock 4 revision 2 on Apple silicon macOS 27.
Other hardware and macOS versions require testing. Mouse control starts
turned off on every launch. This app does not install a kernel extension.
TEXT
if [[ "$mode" == "--development" ]]; then
  cat >> "$staging/Read Me.txt" <<'TEXT'

DEVELOPMENT PREVIEW — NOT NOTARIZED
This build is ad hoc signed. It has no Developer ID distribution signature
or Apple notarization. macOS may block launch. If you trust this project,
review System Settings > Privacy & Security for Open Anyway. Managed Macs
may refuse it. Do not disable Gatekeeper globally. Building from source is
also available. A preview update may require granting permission again.
Downloaded installation on a separate Mac has not yet been validated.
TEXT
fi
hdiutil create -volname "$volume" -srcfolder "$staging" -format UDZO -fs HFS+ "dist/$filename"
hdiutil verify "dist/$filename"
(cd dist && shasum -a 256 "$filename" > "$filename.sha256")
printf 'Created %s/dist/%s\n' "$PWD" "$filename"
