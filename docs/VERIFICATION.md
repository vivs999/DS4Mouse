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

`./scripts/check.sh` runs strict Swift formatting, 33 Swift Testing tests, a release build, signature verification, plist validation, and shell syntax checks. Tests cover report validation, touch-history deduplication, gestures, acceleration and batching, configuration preservation, and bounded local IPC.

## DMG packaging checks

The Apple silicon preview was mounted read-only locally. Its app signature, app and CLI binary equality against the build, bundled CLI help command, and SHA-256 checksum were checked. These packaging checks do not validate Gatekeeper launch or initial permissions on another Mac.

## Checks still needed

- Downloaded installation and permission setup on a separate Mac or clean account.
- Disconnect/reconnect during a drag, sleep/wake, permission revocation, and multiple monitors.
- DualShock 4 revision 1, multiple controllers, Intel Macs, and macOS versions before 27.
- Physical evaluation of the acceleration curve across different pointer settings.
- Developer ID distribution signing and Apple notarization.

The deployment target is macOS 13. Deployment targets and device matching do not establish hardware compatibility. USB is supported by the discovery and report pipeline. DualSense and other controllers are outside the current supported scope.

## Version 0.2.1 USB and permission changes

Wired report tests cover USB contact/button offsets, movement, tap and drag output, touch-history bounds, and truncated packets. Both Sony DS4 product IDs are matched over USB and Bluetooth. Device names include their transport so the settings picker can distinguish connections.

Enabling mouse control no longer opens an automatic Input Monitoring dialog. The explicit settings shortcut is hidden when input access is granted or valid controller reports are received. Clicking a stale shortcut after authorization also does nothing. Mouse-output permission is still required separately.

A Sony revision 2 controller (`054c:09cc`) was detected over USB with 64-byte input reports. Before USB discovery was enabled, the probe received zero reports from the connected controller. Afterward, it received 1,000 reports and validated all 1,000. The installed 0.2.1 app then reported the USB controller selected, mouse-event permission granted, active mouse output, and over 1,100 valid reports. The update retained the previous certificate-backed signing requirement. The user subsequently confirmed that pointer movement, tapping, and dragging work over USB, with no additional Input Monitoring popup.
