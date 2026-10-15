#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
source_app="$project_root/dist/DS4Mouse.app"
destination_app="$HOME/Applications/DS4Mouse.app"
cli_link="$HOME/.local/bin/ds4mouse"
[[ -d "$source_app" ]] || { printf 'Run scripts/build-app.sh first.\n' >&2; exit 1; }
if [[ -e "$destination_app" ]]; then
    printf 'An app already exists at %s. Quit it and move it aside before installing.\n' "$destination_app" >&2
    exit 1
fi
if [[ -e "$cli_link" || -L "$cli_link" ]]; then
    printf 'A CLI entry already exists at %s; it has not been replaced.\n' "$cli_link" >&2
    exit 1
fi
mkdir -p "$HOME/Applications" "$HOME/.local/bin"
ditto "$source_app" "$destination_app"
ln -s "$destination_app/Contents/MacOS/ds4mouse" "$cli_link"
printf 'Installed %s\nCLI: %s\n' "$destination_app" "$cli_link"
printf 'Add ~/.local/bin to PATH if it is not already there.\n'
open "$destination_app"
