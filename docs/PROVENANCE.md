# Protocol provenance

The implementation is original Swift code. No external code is linked or vendored.

The DualShock 4 report layout, packed touch coordinates, active-contact bit, Bluetooth CRC prefix, and extended-mode feature request were checked against SDL's PS4 HID implementation at commit `6defbc0129b5ba90bab3f6c67bbc1e9329e24ff1`: [SDL_hidapi_ps4.c](https://github.com/libsdl-org/SDL/blob/6defbc0129b5ba90bab3f6c67bbc1e9329e24ff1/src/joystick/hidapi/SDL_hidapi_ps4.c). SDL is distributed under the zlib license; its implementation was used as a protocol reference, not copied into this project.

The Linux PlayStation driver was consulted for the structural distinction between basic reports and extended touch history: [hid-playstation.c](https://linux.googlesource.com/linux/kernel/git/torvalds/linux/+/6c790212c588fddeb0d852f2790840753bb604b1/drivers/hid/hid-playstation.c). No Linux driver code was copied.

macOS API declarations were checked in the installed IOKit, CoreGraphics, GameController, AppKit, and SwiftUI SDKs. The controller touch coordinate envelope is 1920 by 944 for validation/normalization; actual usable sensor edges and pointer feel require hardware checks.

CI's checkout action is pinned to the v4 revision resolved through the GitHub API on October 15, 2026.
