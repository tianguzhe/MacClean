#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
[[ $# -eq 0 ]] || fail 'Usage: Scripts/test-packaging.sh'
require_macos
mkdir -p .build

# Exercise the real Xcode tools with Mach-O files, independent of an app build.
work=$(mktemp -d "$MACCLEAN_ROOT/.build/packaging-test.XXXXXX")
trap 'rm -rf "$work"' EXIT
printf 'int main(void) { return 0; }\n' > "$work/main.c"
for arch in arm64 x86_64; do
    xcrun --sdk macosx clang -arch "$arch" -mmacosx-version-min=14.0 "$work/main.c" -o "$work/$arch"
done
/usr/bin/lipo -create "$work/arm64" "$work/x86_64" -output "$work/universal"
verify_architectures "$work/universal"

for arch in arm64 x86_64; do
    if [[ "$arch" == arm64 ]]; then missing=x86_64; else missing=arm64; fi
    if (verify_architectures "$work/$arch") > "$work/check.log" 2>&1; then
        fail "Architecture check accepted a $arch-only binary."
    fi
    if ! /usr/bin/grep -Fq "Missing $missing architecture" "$work/check.log"; then
        cat "$work/check.log" >&2
        fail "Unexpected failure when checking a $arch-only binary."
    fi
    printf 'Correctly rejected %s-only binary (missing %s).\n' "$arch" "$missing"
done
printf 'Packaging checks: 3 passed.\n'
