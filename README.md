# DS4Mouse

<img src="Resources/Branding/logo.png" width="160" alt="DS4Mouse app icon">

Use a Bluetooth DualShock 4 touchpad as a Mac mouse. A menu bar app and CLI share the same saved mouse mappings. The app starts disabled.

This is a local development build. Public signing and notarization require the account steps in [USER-TODO.md](USER-TODO.md). See [verification notes](docs/VERIFICATION.md) for what has actually been tested.

## Build and run

Requires macOS, an Apple Swift 6 toolchain with Swift Testing, and the macOS SDK. Install Apple's Command Line Tools or Xcode. The deployment target is macOS 13; older systems are not yet verified.

```sh
./scripts/test.sh
./scripts/build-app.sh
open dist/DS4Mouse.app
```

Click **DS4** in the menu bar, open **Settings**, and grant Accessibility permission using the button in General. If macOS blocks controller input, check Input Monitoring as well. Pair the controller in macOS Bluetooth settings. Enable mouse control from the menu, settings window, or CLI.

Optional installation copies the app to `~/Applications` and creates `~/.local/bin/ds4mouse`. It refuses to replace an existing app or CLI entry.

```sh
./scripts/install.sh
```

If `~/.local/bin` is not in your PATH, use the full CLI path or add that directory to your shell configuration. A bundled CLI works without installation:

```sh
dist/DS4Mouse.app/Contents/MacOS/ds4mouse on
dist/DS4Mouse.app/Contents/MacOS/ds4mouse off
dist/DS4Mouse.app/Contents/MacOS/ds4mouse status --json
```

## Default controls

| Input | Mouse action |
| --- | --- |
| One-finger movement | Move pointer |
| One-finger tap | Left-click |
| Two-finger tap | Right-click |
| Two-finger movement | Scroll |
| Hold the physical touchpad button and move | Drag |

In Settings → Mappings, change each touch gesture or controller button. Button mappings support clicks, holds, wheel steps, and disabled. Movement can control the pointer or scrolling. Keyboard mappings and analog-stick control are not included.

```sh
ds4mouse map tap left-click
ds4mouse map two-finger-tap right-click
ds4mouse map button-cross hold:left
ds4mouse map button-circle right-click
ds4mouse map button-l1 back-click
ds4mouse map button-r1 forward-click
ds4mouse map two-finger-move scroll
ds4mouse set pointer-speed 1.5
ds4mouse set pointer-acceleration 1.0
ds4mouse set scroll-speed 0.8
ds4mouse set scroll-direction natural
ds4mouse mappings
ds4mouse help
```

Pointer acceleration is adjustable in Settings → Mappings and through `set pointer-acceleration`. The range is 0–3: 0 preserves constant speed, while higher values make faster swipes travel farther. It defaults to 0, including when loading older settings. Pointer speed scales all movement independently.

Settings persist in `~/Library/Application Support/DS4Mouse/config.json`. Changes from either interface apply to the running app. Disabling or replacing mappings releases held mouse buttons. The app adds mouse input without suppressing controller input received by games.

```sh
ds4mouse config export ~/Desktop/ds4mouse-config.json
ds4mouse config import ~/Desktop/ds4mouse-config.json
ds4mouse config reset
```

Export refuses to overwrite a file unless `--force` is supplied. Reset backs up the previous file. A corrupt configuration is reported and preserved until you explicitly reset or import a replacement.

## Diagnostics

`ds4mouse doctor --json` reports the running app's connection and permission state. It does not launch the app or request permissions. `on` can launch the app and returns exit code 4 if it is enabled but waiting for a controller or permission. Other exit codes are 0 for success, 2 for invalid input, and 3 for unavailable service.

For a short controller-only diagnostic that does not move the mouse:

```sh
swift run DS4Probe 10
```

If touch reports remain at zero, confirm the controller is powered on and connected over Bluetooth, check Input Monitoring, and close conflicting remappers. Basic Bluetooth mode triggers one request for extended touch reports. Unsupported or malformed reports do not move the pointer.

App updates and ad hoc development signatures may require granting Accessibility again. Fully quit the previous app before replacing it. Uncatchable termination, such as `kill -9`, cannot perform mouse-button cleanup; use Disable or Quit normally.

## Development and release

`DS4Core` contains configuration, parsing, gestures, and mappings. `DS4Platform` contains HID, mouse output, persistence, and local IPC. `DS4App` provides the GUI; `DS4CLI` provides commands. Tests use Swift Testing. Run `./scripts/check.sh` for formatting, tests, and a release build.

The app has no third-party runtime dependencies. [Protocol provenance](docs/PROVENANCE.md) records the references used for original parsing code. Source is available under the [MIT license](LICENSE). The [GPT-generated icon](docs/BRANDING.md) is included. DS4Mouse is an independent project and is not affiliated with Sony or Apple.

Read [RELEASING.md](docs/RELEASING.md) for Developer ID signing and notarization. CI validates code and builds; it cannot certify Bluetooth gesture quality. No GitHub repository, commit, push, or public release is created by these scripts.

## Privacy and removal

DS4Mouse reads supported Sony controller reports and generates mouse events locally. It does not record keyboard input, contact servers, or collect analytics. Control communication stays on a private socket restricted to the current user. Settings contain mappings and speeds.

Quit the app, then remove `~/Applications/DS4Mouse.app` and the `~/.local/bin/ds4mouse` symlink to uninstall an installed copy. Remove `~/Library/Application Support/DS4Mouse` only if you also want to delete settings and backups. Remove DS4Mouse's entries from macOS privacy settings if desired.
