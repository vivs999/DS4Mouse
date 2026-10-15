# Releasing DS4Mouse

Local builds use an ad hoc signature. This checks bundle integrity but does not establish a trusted publisher or constitute notarization.

The source uses MIT, the repository is `vivs999/DS4Mouse`, and the app identifier is `io.github.vivs999.DS4Mouse`. Review compatibility claims against [VERIFICATION.md](VERIFICATION.md). Follow [USER-TODO.md](../USER-TODO.md) for Apple account prerequisites.

Use a Developer ID Application certificate with its private key in Keychain. Configure a named `notarytool` Keychain profile using Apple's supported authentication workflow. Keep credentials outside the project. Set `DS4_SIGN_IDENTITY` to the identity name and `DS4_NOTARY_PROFILE` to the profile name, then run:

```sh
./scripts/release.sh
```

The script runs local checks, signs the bundled CLI and app with Hardened Runtime and timestamps, submits a ZIP to Apple's notary service, requires acceptance, staples the ticket, validates Gatekeeper assessment, and creates a ZIP plus SHA-256 checksum. Running this script sends the build to Apple for notarization; it does not publish to GitHub.

Verify the resulting downloaded artifact on a separate user account or Mac, including initial launch, Accessibility permissions, Bluetooth connection, both tap gestures, scrolling, dragging, disable during drag, and reconnect. Check both controller revisions before claiming both are hardware-tested. Test each macOS version listed as supported.

Only publish after the user's explicit request. A public source repository does not require an Apple certificate. The signed app release process does. Apple notarization is an automated security/signature check, not a functional certification or App Store review. [Apple distribution documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
