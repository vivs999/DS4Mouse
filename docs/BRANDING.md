# DS4Mouse icons

Both current icons reuse one GPT-generated DualShock 4 controller-and-pointer mark. The rounded controller body, outward grips, rectangular touchpad, d-pad, four buttons, and symmetric analog sticks distinguish it from the earlier artwork.

- `Resources/Branding/dualshock4-mark-cursor-inside-original.png`: current generated transparent original.
- `Resources/Branding/dualshock4-mark.png`: trimmed and centered 1024 × 1024 master.
- `Resources/MenuBarIcon.png`: 88 × 88 transparent export; displayed as a 22 × 22-point AppKit template inside a 26-point status item, with two points of side spacing.
- `Resources/Branding/logo.png`: 1024 × 1024 app icon, using the exact same master mask tinted white over a blue rounded-square background.
- `Resources/AppIcon.icns`: standard macOS icon representations of the app icon.

The menu bar template adapts to light and dark appearances. Neither version stretches the controller. The app composition is rendered with AppKit by `swift scripts/render-app-icon.swift`; its controller mask is shared rather than separately generated, so both controller shapes remain identical.

Generation: GPT image generation, transparent-background edit, October 15, 2026. Prompt requested a compact black DualShock 4/PS4 silhouette with short rounded outward grips, broad rectangular touchpad, separate d-pad and four round buttons, symmetric low analog sticks, and a small mouse cursor entirely inset within the touchpad. The earlier arrow extending above the controller was removed. Square composition, transparent cutouts, bold geometry, no background, text, branding, shadows, or DualSense shell panels. Earlier generated assets remain as design history.
