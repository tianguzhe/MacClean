#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
if [[ $# -gt 1 ]] || { [[ $# -eq 1 ]] && [[ "$1" != --skip-build ]]; }; then
    fail 'Usage: Scripts/build-dmg.sh [--skip-build]'
fi
require_macos
# Apple's bundled python3 can still be 3.9; dmgbuild requires Python 3.10+.
python_bin="${MACCLEAN_PYTHON:-}"
if [[ -z "$python_bin" ]]; then
    for candidate in python3 python3.14 python3.13 python3.12 python3.11 python3.10; do
        if command -v "$candidate" >/dev/null 2>&1 &&
           "$candidate" -c 'import sys; raise SystemExit(sys.version_info < (3, 10))' >/dev/null 2>&1; then
            python_bin="$candidate"
            break
        fi
    done
fi
[[ -n "$python_bin" ]] || fail 'Python 3.10+ is required. Set MACCLEAN_PYTHON to a compatible interpreter.'
"$python_bin" -c 'import sys; raise SystemExit(sys.version_info < (3, 10))' ||
    fail 'MACCLEAN_PYTHON must point to Python 3.10 or newer.'

if [[ "${1:-}" != --skip-build ]]; then
    bash Scripts/build.sh
fi
verify_app "$MACCLEAN_APP"

venv="$MACCLEAN_ROOT/.build/dmg-venv"
work="$MACCLEAN_ROOT/.build/dmg"
mkdir -p "$work" dist
if [[ ! -x "$venv/bin/python" ]] ||
   ! "$venv/bin/python" -c 'import sys; raise SystemExit(sys.version_info < (3, 10))'; then
    "$python_bin" -m venv --clear "$venv"
fi
# Read exact versions from the same requirements file used by pip and CI caching.
if ! "$venv/bin/python" - Scripts/dmg-requirements.txt <<'PY'
import sys
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path

try:
    for line in Path(sys.argv[1]).read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            name, expected = line.split("==")
            if version(name) != expected:
                raise SystemExit(1)
except PackageNotFoundError:
    raise SystemExit(1)
PY
then
    run_logged .build/dmg-dependencies.log "$venv/bin/python" -m pip --disable-pip-version-check install \
        -r Scripts/dmg-requirements.txt
fi
"$venv/bin/python" -m pip check

printf 'Rendering Retina installer artwork…\n'
run_logged .build/dmg-artwork.log xcrun swift -module-cache-path .build/icon-module-cache Scripts/generate-dmg-background.swift
printf 'Creating drag-to-install DMG…\n'
run_logged .build/dmg-build.log "$venv/bin/python" -m dmgbuild \
    -s Scripts/dmg-settings.py -D "app=$MACCLEAN_APP" \
    -D "background=$MACCLEAN_ROOT/Assets/Installer/background.png" \
    'MacClean 安装' "$work/MacClean.dmg"
/usr/bin/hdiutil verify "$work/MacClean.dmg"

# Check the final compressed image too: Finder metadata can invalidate signatures.
verify_mount=""
cleanup() {
    if [[ -n "$verify_mount" ]]; then
        /usr/bin/hdiutil detach -quiet "$verify_mount" 2>/dev/null || true
        rmdir "$verify_mount" 2>/dev/null || true
    fi
}
trap cleanup EXIT
verify_mount=$(mktemp -d "${TMPDIR:-/tmp}/MacClean-dmg-check.XXXXXX")
/usr/bin/hdiutil attach -readonly -nobrowse -mountpoint "$verify_mount" "$work/MacClean.dmg" >/dev/null
verify_app "$verify_mount/MacClean.app"
cmp "$MACCLEAN_APP/Contents/MacOS/MacClean" "$verify_mount/MacClean.app/Contents/MacOS/MacClean"
cmp "$MACCLEAN_APP/Contents/Resources/Assets.car" "$verify_mount/MacClean.app/Contents/Resources/Assets.car"
[[ "$(readlink "$verify_mount/Applications")" == /Applications ]] || fail 'Invalid Applications shortcut in DMG.'
/usr/bin/hdiutil detach -quiet "$verify_mount"
rmdir "$verify_mount"
verify_mount=""

# Publish local artifacts only after every verification succeeds.
(cd "$work" && /usr/bin/shasum -a 256 MacClean.dmg > MacClean.dmg.sha256)
/bin/mv -f "$work/MacClean.dmg" dist/MacClean.dmg
/bin/mv -f "$work/MacClean.dmg.sha256" dist/MacClean.dmg.sha256
(cd dist && /usr/bin/shasum -a 256 -c MacClean.dmg.sha256)
printf '\nInstaller: %s/dist/MacClean.dmg\nChecksum: %s/dist/MacClean.dmg.sha256\n' "$MACCLEAN_ROOT" "$MACCLEAN_ROOT"
