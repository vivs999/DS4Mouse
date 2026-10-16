# Compatibility and verification

## Hardware checks

Verified on Apple silicon, macOS 27.0.1, using a Sony DualShock 4 revision 2 (`054c:09cc`) over Bluetooth:

- Pointer movement, one-finger tap, two-finger tap, two-finger scrolling, and touchpad-button dragging.
- GUI and CLI mapping changes reflected in each other.
- CLI status, enable, configuration export, and live report reception.
- Mouse-event authorization and recovery from a stale permission entry.
- Permission UI disappears after authorization and working controller input.
- A certificate-backed local development update retained its existing permission.

These checks used a locally installed build. They do not validate a downloaded DMG on a clean Mac. The preview DMG uses ad hoc signing; it does not have the stable certificate identity used by the local development installation.

## Automated checks

`./scripts/check.sh` runs strict Swift formatting, 29 Swift Testing tests, a release build, signature verification, plist validation, and shell syntax checks. Tests cover report validation, touch-history deduplication, gestures, acceleration and batching, configuration preservation, and bounded local IPC.

## DMG packaging checks

The Apple silicon preview was mounted read-only locally. Its app signature, app and CLI binary equality against the build, bundled CLI help command, and SHA-256 checksum were checked. These packaging checks do not validate Gatekeeper launch or initial permissions on another Mac.

## Checks still needed

- Downloaded installation and permission setup on a separate Mac or clean account.
- Disconnect/reconnect during a drag, sleep/wake, permission revocation, and multiple monitors.
- DualShock 4 revision 1, multiple controllers, Intel Macs, and macOS versions before 27.
- Physical evaluation of the acceleration curve across different pointer settings.
- Developer ID distribution signing and Apple notarization.

The deployment target is macOS 13. Deployment targets and device matching do not establish hardware compatibility. USB, DualSense, and other controllers are outside the current supported scope.
