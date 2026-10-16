# Releasing DS4Mouse

## Development preview DMG

The preview is for testers. It is ad hoc signed, without Developer ID distribution signing or Apple notarization. Gatekeeper may block it. Never label it notarized or broadly compatible.

```sh
DS4_LOCAL_SIGN_IDENTITY=- ./scripts/check.sh
./scripts/build-dmg.sh --development
```

The DMG contains DS4Mouse.app, an Applications shortcut, a short installation guide, and the MIT license. The CLI is inside the app bundle. Outputs and SHA-256 checksums are written to `dist/`; they are not source-controlled. The architecture label is derived from the built executable.

## Developer ID distribution

A paid Apple Developer Program membership, a Developer ID Application certificate and private key in Keychain, and a named `notarytool` Keychain profile are required. These prerequisites are not configured for the preview. Keep all credentials outside the repository.

```sh
export DS4_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export DS4_NOTARY_PROFILE='your-notary-profile'
./scripts/release.sh
```

The release script checks the source, signs the CLI and app with Hardened Runtime and timestamps, notarizes and staples the app, then packages, signs, notarizes, and staples the DMG. It requires accepted notarization results and validates the tickets. It does not publish to GitHub. Apple notarization checks software signatures and security; it is not functional certification or App Store review.

Before publishing, verify the downloaded artifact on another Mac, including launch, permissions, USB and Bluetooth connections, taps, scrolling, dragging, disable during drag, and reconnect. Review [VERIFICATION.md](VERIFICATION.md) before making compatibility claims. Publish only the intended DMG and checksum, without notarization logs or credentials.

Local source builds select an available Apple Development certificate to preserve privacy identity across updates. `DS4_LOCAL_SIGN_IDENTITY` overrides it; `-` requests ad hoc signing. Apple Development signing is not Developer ID distribution signing. Replacing an ad hoc build can require granting mouse-control permission again.

[Apple notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
