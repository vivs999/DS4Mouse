# DS4Mouse user and release checklist

Updated October 15, 2026. Local functionality is verified on the user's Bluetooth controller. This checklist separates local testing from public distribution. Apple Developer ID signing and notarization remain blocked on the account prerequisites below.

## Needed for local use after the app is built

- [x] Grant DS4Mouse permission to generate mouse events. The installed app reports permission granted and active mouse output.
- [x] Check pointer movement, one-finger tap, two-finger tap, two-finger scrolling, and physical-button dragging. The user confirmed all five work over Bluetooth.
- [ ] Before a public release, check disconnect/reconnect during dragging, sleep/wake, and the other unverified scenarios in [VERIFICATION.md](docs/VERIFICATION.md).

No paid Apple developer membership is needed merely to build the source and test it locally. A local development build will be labeled separately from a signed public release.

## User decisions before publishing source

- [x] Public source repository: `vivs999/DS4Mouse`.
- [x] MIT license, copyright Vivaan Rochlani (approved).
- [x] DS4Mouse; bundle identifier `io.github.vivs999.DS4Mouse`.
- [x] User explicitly requested GitHub publication.

Publishing source does not require an Apple code-signing certificate. A certificate is relevant to the downloadable macOS app distribution workflow.

## User prerequisites for a signed public app

- [ ] Confirm access to an Apple Developer Program membership with permission to create Developer ID certificates. If enrollment or payment is required, complete that personally.
- [ ] Obtain or import a **Developer ID Application** certificate with its matching private key into the login Keychain. This Mac has an Apple Development identity, but no Developer ID Application identity. Apple Development does not satisfy notarization requirements.
- [ ] Configure notarization authentication through Apple's supported workflow. Use a named Keychain profile or carefully scoped CI secrets; do not paste passwords, private keys, or API keys into this chat or the repository.
- [ ] Complete any Apple account sign-in, two-factor authentication, account agreement, or identity verification yourself.

Apple issues Developer ID certificates to members of its developer programs. A Developer ID Application certificate signs the app; a Developer ID Installer certificate is for installer packages and is not planned for the app-in-ZIP distribution. [Apple certificate reference](https://developer.apple.com/help/glossary/developer-id-certificate/)

## Engineering checks to complete before releasing binaries

These are implementation/release tasks for the agent once the required approvals and credentials are available.

- [x] Pass local lint/format checks, compiler checks, 28 tests, app build, local signature validation, plist validation, and shell syntax checks.
- [ ] Run the clean-checkout build and configured macOS CI after the repository is created.
- [ ] Record hardware tests and accurately label tested macOS versions and controller revisions.
- [x] Check third-party provenance, licensing, ignored files, and absence of secrets/private data.
- [ ] Sign all shipped executables with Developer ID Application, Hardened Runtime, and secure timestamps; exclude debug entitlements.
- [ ] Submit with `notarytool`, inspect the result/log, and require acceptance.
- [ ] Staple and validate the ticket, then package the signed app and generate a checksum.
- [ ] Validate signatures and Gatekeeper assessment; test installation and launch of a downloaded artifact, including its permission setup.
- [ ] Publish only after an explicit user request, and distinguish completed checks from remaining manual verification.

Apple notarization checks software for malicious content and signing issues. It is not App Store review and does not certify gesture correctness. [Apple notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
