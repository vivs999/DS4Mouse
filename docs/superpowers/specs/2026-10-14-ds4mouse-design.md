# DS4Mouse design specification

Date: October 14, 2026
Status: Implemented; see verification record for tested behavior.
Working product name: DS4Mouse

## 1. Purpose and agreed scope

Use a Bluetooth-connected Sony DualShock 4 touchpad as a Mac mouse. The user must be able to enable or disable it from a menu bar app or a CLI, and customize mouse mappings through both interfaces.

The user approved these defaults:

| Input | Default action |
| --- | --- |
| One-finger movement | Move the pointer |
| One-finger tap | Left-click |
| Two-finger tap | Right-click |
| Two-finger movement | Scroll vertically and horizontally |
| Hold the physical touchpad button while moving | Hold the left mouse button and drag |

Custom mappings generate mouse actions only. Keyboard shortcuts, macros, shell commands, analog-stick pointer control, and automatic game profiles are outside the first release. The app adds mouse input; it does not suppress the controller input received by games or macOS.

The user also requested implementation suitable for later GitHub publication, including signing requirements or a clear list of user actions. This authorizes local preparation. Commits, pushes, repository publication, and release publication require a separate explicit request.

## 2. Verified environment and remaining evidence

Read-only checks found:

- macOS 27.0.1, build 26A434, on arm64.
- Apple Swift 6.4 and Command Line Tools; `notarytool` is available.
- A Bluetooth DualShock 4 with Sony vendor ID `0x054c` and product ID `0x09cc`.
- No valid code-signing identities in the current keychain search list. This does not establish whether the user has an Apple Developer membership or certificates stored elsewhere.
- No existing source project or Git repository in the working directory.

Apple's installed SDK exposes DualShock touch positions and its touchpad button through GameController. Its DualShock direction-pad interface does not directly expose a finger-contact lifecycle. IOKit exposes device input-report callbacks and nonexclusive device access.

Live report delivery, contact flags, touch history, and gesture quality have not been tested. The first implementation milestone must verify those properties with the connected controller before enabling generated mouse events.

## 3. Approach

Build a native Swift application using AppKit for application lifetime and the menu bar, SwiftUI for settings, IOKit for controller reports, and CoreGraphics for mouse events. Package a separate CLI executable with the app. Both interfaces use one running app process as the owner of controller input, configuration changes, and generated mouse events.

Direct controller reports provide the input needed to track contact identity and release. A GameController-only implementation would reduce parsing, but its touch semantics need additional validation. A Python implementation would introduce a separate runtime and packaging dependencies. The selected approach is native Swift with a narrowly scoped HID transport and independently tested parser.

The application runs as the logged-in user. It does not install a kernel extension, system extension, privileged helper, or system daemon. There are no third-party runtime dependencies planned for version one.

Use a macOS 13 deployment target and Swift 6 language mode, subject to verification against the build SDK and CI toolchain. The first binary release targets Apple silicon. Older macOS versions and Intel hardware must not be advertised as tested without corresponding evidence.

## 4. Components and data flow

`Controller report → validated input frame → gesture recognition → mapping resolution → mouse events`

| Component | Responsibility | Boundary |
| --- | --- | --- |
| HID transport | Discover, open, read, and reconnect supported devices | Emits raw report bytes and connection events; does not move the pointer |
| DS4 parser | Validate reports and decode contacts/buttons | Pure transformations with no AppKit, permissions, or device access |
| Gesture engine | Recognize motion, taps, scrolling, and holds | Consumes frames and monotonic time; emits input actions |
| Mapping model | Validate mappings and resolve actions | Shared by the app, CLI, tests, and configuration persistence |
| Mouse output | Post movement, scroll, click, and release events | The app is the only process that generates events |
| App coordinator | Own enable state, selected device, permissions, and lifecycle | Serializes transitions and configuration changes |
| GUI | Menu bar state, settings, mappings, and permission guidance | Uses coordinator operations |
| Local command server and CLI | Expose the same operations to scripts | Versioned requests over a private local socket |

Keep source files focused, normally below 300 lines. Keep parser and gesture logic independent of device callbacks and UI code so tests can exercise real behavior without hardware.

## 5. Controller input contract

Match Sony DualShock 4 devices by vendor/product IDs, initially `0x054c:0x05c4` and `0x054c:0x09cc`. Bluetooth is the required transport. USB and third-party clones are not release claims for version one.

Open devices nonexclusively. If another process prevents access, report the conflict rather than taking exclusive ownership. When several supported controllers are connected, use one selected controller; the settings window identifies the active device and allows selection. Do not silently switch to a different controller during a gesture.

The diagnostic milestone must establish the actual callback report format, extended-report availability, and contact/button semantics. If extended reporting requires a controller feature request, use a bounded, documented initialization sequence specific to supported devices. Do not send experimental output reports, rumble commands, or continuous initialization requests.

The parser must validate report ID, length, coordinate bounds, contact validity, and applicable report integrity fields before reading fields or emitting a frame. It must account for repeated touch history and counter wraparound. Track contact identities rather than assuming the first report slot always contains the same finger.

Malformed, unsupported, or stale data must never generate mouse input. Ignore unrelated report types. Five consecutive malformed reports of a supported input type, or one second without a valid input report while output is active, suspend output and release held buttons. Recovery requires a valid fresh frame and a new gesture baseline. If the required data cannot be read on this Mac, provide a diagnostic result and revisit the input approach before implementing a substitute based on ambiguous coordinates.

Diagnostics may display sanitized contact positions, contact IDs, and button transitions. Persistent logs must not contain Bluetooth addresses, serial numbers, unrelated HID reports, or credentials.

## 6. Gestures and custom mappings

Pointer movement is relative to the current cursor location. Establish a baseline on contact start, identity changes, and transitions between one and two contacts. A new contact must not jump the cursor to an absolute screen position. Keep subpixel remainder so slow movement is not lost. Respect the layout and scale of attached displays.

Initial tap thresholds are a maximum of 250 ms from first contact down to final contact up and maximum normalized displacement of 0.015 along either touchpad axis for each participating finger. A two-finger tap requires overlapping contacts, with the second contact arriving within 100 ms of the first. Once two contacts participate, suppress the one-finger tap for that gesture. Evaluate the tap only when all contacts lift. These are tuning defaults to verify with hardware, not claims of measured performance.

Motion exceeding the tap threshold cancels tapping. Two-finger scrolling and physical-button dragging suppress tap generation. If a physical mouse-button hold is active, use primary-contact motion for dragging and suppress two-finger scrolling until release. When a second finger leaves a scroll gesture, reset the single-finger baseline before resuming movement.

Supported configurable inputs:

- One-finger movement and two-finger movement.
- One-finger tap and two-finger tap.
- Touchpad press, face buttons, L1/R1, L2/R2 presses, D-pad directions, L3/R3, Share, and Options.

Other controller buttons are unassigned by default. PS/system-button behavior is outside the mapping editor because the operating system may handle it. Trigger presses use a press threshold of 0.55 and a release threshold of 0.45 to prevent threshold chatter.

| Input kind | Allowed actions |
| --- | --- |
| Continuous movement | Pointer movement, two-axis scrolling, disabled |
| Tap | Left/right/middle/back/forward click, left double-click, one scroll step in a selected direction, disabled |
| Physical button | The tap actions above, or hold a selected mouse button until physical release |

Discrete button actions fire once per press. They do not repeat while held. A discrete scroll step is three line units before the scroll-speed multiplier. Holding a mapped mouse button supplies dragging when combined with pointer movement. Track each held action's owner so releasing one of two inputs mapped to the same mouse button does not release the other input's hold. Give repeated clicks appropriate click counts using the system double-click interval and movement tolerance, so two ordinary taps can also activate a double-click.

The GUI and CLI reject incompatible mappings with an actionable error and leave the previous configuration intact. Mappings, pointer speed, scroll speed, and scroll direction persist. Version one has one active mapping configuration, plus export/import and reset-to-defaults operations; named profile switching is outside scope.

## 7. Application behavior and GUI

The app has a menu bar icon with Enable/Disable, connection state, Settings, and Quit. Settings includes device status, a mapping editor, pointer and scroll controls, reset/export/import, and permission guidance. Controls must be keyboard accessible, clearly labeled for VoiceOver, and show the current value without relying only on color.

Every fresh launch starts disabled. Settings persist, but enabled state does not persist across app restarts. An explicit CLI `on` or `toggle` may launch and enable the app. Automatic login launch is outside the first release.

Separate the user's desired enabled state from readiness. For example, enabling with no controller connected displays “Enabled — waiting for controller” while generating no input. Reconnection resumes only after clearing previous gesture state and obtaining valid fresh input.

Check mouse-event permission and explain how to grant it through macOS. Request only permissions the chosen APIs require; direct HID access may also require Input Monitoring depending on system behavior. The user completes any protected permission prompt. Permission denial must leave the UI and CLI usable.

Disable, quit, device loss, permission loss, sleep, mapping replacement, or selected-device change releases all generated held buttons where posting remains permitted and clears gesture state. Wake and reconnection require a fresh baseline. Keep an internal record of held output and make a best-effort release on termination. Tests and documentation must distinguish graceful cleanup from an uncatchable process kill, where cleanup cannot be guaranteed.

## 8. CLI, persistence, and local communication

The packaged CLI is `ds4mouse`. It supports:

```text
ds4mouse on
ds4mouse off
ds4mouse toggle
ds4mouse status [--json]
ds4mouse mappings [--json]
ds4mouse map tap left-click
ds4mouse map two-finger-tap right-click
ds4mouse map touchpad-press hold:left
ds4mouse map button-cross middle-click
ds4mouse set pointer-speed 1.5
ds4mouse set scroll-speed 1.0
ds4mouse set scroll-direction natural
ds4mouse config export <path>
ds4mouse config import <path>
ds4mouse config reset
ds4mouse doctor [--json]
```

Document all accepted input/action names in generated CLI help and the README. Speeds are finite multipliers from 0.1 to 5.0; default 1.0. The GUI exposes the same range. Natural scrolling is the default, with a traditional direction option.

`status` and `doctor` do not start the app or request permission. `off` succeeds when the app is already stopped. `on` and `toggle` start the app when necessary. Configuration commands may start the app disabled to use the single configuration writer. Invalid command syntax must not launch the app. The CLI locates its containing app bundle without relying on the caller's working directory.

Use exit codes 0 for success, 2 for invalid usage/configuration, 3 for unavailable app/connection, and 4 when an enable request is accepted but permission or device readiness prevents output. The latter retains the desired enabled state and reports why it is waiting. Informational commands return 0 when the query succeeds, even if the app is stopped. JSON responses contain protocol version, command outcome, desired enabled state, readiness, and a human-readable diagnostic when relevant. Human output distinguishes waiting for a controller from actively generating mouse events.

Use a Unix-domain socket in a system-provided private per-user temporary directory. Validate path length, ownership, permissions, and peer user ID. Limit request size to 64 KiB and set bounded connection/read timeouts. Do not listen on a TCP port. Detect existing app instances and handle stale sockets without deleting arbitrary paths.

Store a versioned JSON configuration in `~/Library/Application Support/DS4Mouse/config.json`. Validate the entire candidate before saving, write atomically with user-only permissions, and preserve the last valid configuration if a write fails. On startup, a corrupt or unsupported-version file produces a visible diagnostic and disabled operation; never silently overwrite the file. Export/import replaces configuration only after validation, and export must not overwrite an existing file without an explicit CLI flag or GUI confirmation.

## 9. Repository and release engineering

The eventual project root is `outputs/DS4Mouse`. Use Swift Package Manager targets for the core, app, CLI, and tests, with scripts for assembling the app bundle, local installation, validation, and release packaging. Pin tooling versions where they affect builds. Keep local caches and build outputs out of version control.

Repository documentation must cover setup, build/run commands, permissions, mappings, CLI examples, uninstall, supported/tested environments, known limitations, privacy, contributing, troubleshooting, and the release procedure. A clean checkout must build without private files or a paid account. Ordinary CI must not need signing credentials.

Provide formatting/lint validation, compiler/type checking, unit tests, and a release build in macOS CI. Select and record a compatible CI SDK/toolchain during implementation. Local and CI checks must use the same entry points. Automated CI can verify builds and pure logic; Bluetooth hardware validation remains a separately documented manual check.

Use original parser code. If protocol references or third-party material are used, record their provenance and respect their licenses. Do not copy incompatible source into the project. The user chooses the repository license and publisher identity before publication; this is an explicit release task, not a blocker to local development.

For a public downloadable app, prepare Developer ID Application signing, Hardened Runtime, secure timestamps, notarization through `notarytool`, ticket stapling, signature validation, and Gatekeeper assessment. Sign every shipped executable. Do not include debug entitlements in release artifacts. Use a ZIP containing the app; no installer package is planned, so no Developer ID Installer certificate is needed for that package choice. See Apple's [notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and [certificate types](https://developer.apple.com/help/glossary/developer-id-certificate/).

Keep signing private keys and notarization credentials in the user's Keychain or appropriately scoped CI secrets. Never put them in source, logs, exported configuration, or build artifacts. A signed release must retain a stable bundle identifier and installation path; development rebuilds can require users to revisit Accessibility permission.

No certificate issuance, developer enrollment, notarization, signing success, or GitHub publication has occurred. Work that depends on the user's account or release decision is tracked in [USER-TODO.md](../../../USER-TODO.md).

## 10. Verification and acceptance criteria

Automated coverage must include:

- Valid and truncated reports, unknown report IDs, invalid contacts, repeated history, contact-slot changes, and counter wraparound.
- Touch down/move/up, one- and two-finger taps, tap cancellation, transitions to/from scrolling, physical dragging, and trigger hysteresis.
- Two inputs holding the same mouse button, release on disable/disconnect/configuration change, and multiple displays' coordinate handling.
- Valid and invalid mappings, speed ranges, configuration versions, atomic-save failures, and corrupt-file recovery behavior.
- CLI argument parsing, stopped-app behavior, socket ownership/peer rejection, bounded requests, malformed responses, and configuration consistency between interfaces.

Hardware acceptance must verify each default gesture, representative custom mappings from both interfaces, pointer feel, screen boundaries, disabling during a drag, Bluetooth disconnect/reconnect, sleep/wake, permission denial, and clean uninstall. Test both DS4 revisions before claiming both are hardware-verified. Record exact OS, architecture, controller revision, and results.

A local implementation is complete when build checks pass and observed hardware behavior meets the agreed controls, with any unperformed checks called out. Public release readiness additionally requires license/publisher decisions, the applicable signing and notarization checks, and an explicit publication request. Lack of a Developer ID certificate must not prevent delivery of source and a clearly labeled local development build.

## 11. Official references

- [Apple: DualShock controller profile](https://developer.apple.com/documentation/gamecontroller/gcdualshockgamepad)
- [Apple: Distributing software on macOS](https://developer.apple.com/macos/distribution/)
- [Apple: Developer ID certificate](https://developer.apple.com/help/glossary/developer-id-certificate/)
- [Apple: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- Installed macOS SDK headers: `GCDualShockGamepad.h`, `GCControllerDirectionPad.h`, `IOHIDDevice.h`, and `CGEvent.h`.

Apple documents the distribution requirements above. Device reporting details and user experience still require implementation-time hardware verification.
