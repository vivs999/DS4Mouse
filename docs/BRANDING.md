# Icon artwork

The app and menu bar icons share one GPT-generated DualShock 4 controller mark, with a small cursor inside its rectangular touchpad. Artwork was generated on October 15, 2026.

- `Resources/Branding/dualshock4-mark.png`: transparent 1024 × 1024 master, preserving the controller proportions.
- `Resources/Branding/logo.png`: the same mask tinted white over a blue rounded-square background.
- `Resources/MenuBarIcon.png`: transparent 88 × 88 export, displayed as a 22-point template inside a 26-point menu bar item.
- `Resources/AppIcon.icns`: macOS app icon representations.

Run `swift scripts/render-app-icon.swift` to render the blue app artwork from the shared master. The menu bar template adapts to light and dark appearances. Source artwork and exported icons are included under the repository's MIT license. DS4Mouse is independent of Sony and Apple.
