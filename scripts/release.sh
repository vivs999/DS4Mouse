#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DS4_SIGN_IDENTITY:?Set DS4_SIGN_IDENTITY to your Developer ID Application identity}"
: "${DS4_NOTARY_PROFILE:?Set DS4_NOTARY_PROFILE to your notarytool Keychain profile name}"
[[ "$DS4_SIGN_IDENTITY" == "Developer ID Application:"* ]] || {
    printf 'A Developer ID Application identity is required.\n' >&2; exit 1;
}
./scripts/check.sh
bundle="$PWD/dist/DS4Mouse.app"
codesign --force --options runtime --timestamp --sign "$DS4_SIGN_IDENTITY" "$bundle/Contents/MacOS/ds4mouse"
codesign --force --options runtime --timestamp --sign "$DS4_SIGN_IDENTITY" "$bundle"
codesign --verify --deep --strict "$bundle"
ditto -c -k --keepParent "$bundle" dist/DS4Mouse-notary.zip
xcrun notarytool submit dist/DS4Mouse-notary.zip --keychain-profile "$DS4_NOTARY_PROFILE" --wait --output-format json > dist/notarization.json
notary_status="$(plutil -extract status raw -o - dist/notarization.json)"
[[ "$notary_status" == "Accepted" ]] || { printf 'Notarization was not accepted. Inspect dist/notarization.json.\n' >&2; exit 1; }
xcrun stapler staple "$bundle"
xcrun stapler validate "$bundle"
spctl --assess --type execute --verbose=2 "$bundle"
./scripts/build-dmg.sh --release
version="$(plutil -extract CFBundleShortVersionString raw -o - "$bundle/Contents/Info.plist")"
# Packaging derives the architecture from the executable, as does this lookup.
architecture="$(lipo -archs "$bundle/Contents/MacOS/DS4MouseApp")"
case "$architecture" in 'x86_64 arm64'|'arm64 x86_64') architecture="universal" ;; esac
dmg="dist/DS4Mouse-${version}-macos-${architecture}.dmg"
codesign --force --timestamp --sign "$DS4_SIGN_IDENTITY" "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$DS4_NOTARY_PROFILE" --wait --output-format json > dist/dmg-notarization.json
[[ "$(plutil -extract status raw -o - dist/dmg-notarization.json)" == "Accepted" ]] || {
  printf 'DMG notarization was not accepted. Inspect dist/dmg-notarization.json.\n' >&2
  exit 1
}
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
hdiutil verify "$dmg"
(cd dist && shasum -a 256 "$(basename "$dmg")" > "$(basename "$dmg").sha256")
printf 'Signed packages prepared locally. Nothing was uploaded to GitHub.\n'
