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
ditto -c -k --keepParent "$bundle" dist/DS4Mouse-macos-arm64.zip
shasum -a 256 dist/DS4Mouse-macos-arm64.zip > dist/DS4Mouse-macos-arm64.zip.sha256
printf 'Signed package prepared locally. Nothing was uploaded to GitHub.\n'
