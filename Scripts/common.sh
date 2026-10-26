#!/bin/bash
# Shared by the build and packaging entry points; compatible with macOS Bash 3.2.
MACCLEAN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$MACCLEAN_ROOT"
MACCLEAN_APP="$MACCLEAN_ROOT/dist/MacClean.app"
MACCLEAN_VERSION=$(bash Scripts/version.sh)
MACCLEAN_BUILD=$(bash Scripts/version.sh --build)
export CLANG_MODULE_CACHE_PATH="$MACCLEAN_ROOT/.build/clang-cache"

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

require_macos() {
    [[ "$(uname -s)" == Darwin ]] || fail 'This script requires macOS and Xcode.'
    xcrun --find swift >/dev/null
}

run_logged() {
    local log="$1"
    shift
    mkdir -p "$(dirname "$log")"
    local result=0
    "$@" >"$log" 2>&1 || result=$?
    if [[ "$result" -ne 0 ]]; then
        tail -n 80 "$log" >&2
        printf '\nFull log: %s\n' "$log" >&2
        return "$result"
    fi
}

verify_app() {
    local app="$1"
    [[ -d "$app" ]] || fail "Missing app: $app. Run Scripts/build.sh first."
    local plist="$app/Contents/Info.plist"
    [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$plist")" == "$MACCLEAN_VERSION" ]] ||
        fail 'App version is stale. Run Scripts/build.sh again.'
    [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$plist")" == "$MACCLEAN_BUILD" ]] ||
        fail 'App build number is stale. Run Scripts/build.sh again.'
    # Check each slice separately (also works with lipo versions that consume
    # multiple -verify_arch arguments as input filenames).
    local arch
    for arch in arm64 x86_64; do
        /usr/bin/lipo -verify_arch "$arch" "$app/Contents/MacOS/MacClean"
    done
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$app"
}
