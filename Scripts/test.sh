#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
[[ $# -eq 0 ]] || fail 'Usage: Scripts/test.sh'
require_macos

# Keep generated files and SwiftPM caches inside this checkout.
run_logged .build/test.log swift test --scratch-path .build/tests \
    --cache-path .build/package-cache --config-path .build/package-config \
    --security-path .build/package-security \
    -Xswiftc -module-cache-path -Xswiftc "$MACCLEAN_ROOT/.build/swift-cache"
tail -n 24 .build/test.log
bash Scripts/test-packaging.sh
