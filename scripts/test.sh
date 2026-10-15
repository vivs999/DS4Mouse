#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift_compiler="$(xcrun --find swiftc)"
plugin_dir="$(dirname "$swift_compiler")/../lib/swift/host/plugins/testing"
if [[ -f "$plugin_dir/libTestingMacros.dylib" ]]; then
    swift test --disable-xctest -Xswiftc -plugin-path -Xswiftc "$plugin_dir" "$@"
else
    swift test --disable-xctest "$@"
fi
