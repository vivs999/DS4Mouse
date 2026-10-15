#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift format lint --strict --recursive Sources Tests Package.swift
./scripts/test.sh
./scripts/build-app.sh
plutil -lint Resources/Info.plist
for script in scripts/*.sh; do bash -n "$script"; done
