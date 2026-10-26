#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
[[ $# -eq 0 ]] || fail 'Usage: Scripts/build.sh'
require_macos
mkdir -p .build dist

# Brand PDFs are checked in; regular builds need neither Node.js nor network access.
if [[ ! -f Assets.xcassets/AppIcon.appiconset/icon_512@2x.png ]] ||
   [[ Scripts/generate-icon.swift -nt Assets.xcassets/AppIcon.appiconset/icon_512@2x.png ]] ||
   [[ ! -f Assets.xcassets/MacCleanMark.imageset/mark.pdf ]]; then
    printf 'Rendering app icon…\n'
    run_logged .build/icon-build.log xcrun swift -module-cache-path .build/icon-module-cache Scripts/generate-icon.swift
fi

printf 'Building MacClean %s (%s), Apple Silicon + Intel…\n' "$MACCLEAN_VERSION" "$MACCLEAN_BUILD"
run_logged .build/build.log xcodebuild -project MacClean.xcodeproj -scheme MacClean \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath .build/xcode 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO build

# Copy to a fresh bundle so files removed from the project cannot survive a rebuild.
staging=$(mktemp -d "$MACCLEAN_ROOT/.build/app-stage.XXXXXX")
trap 'rm -rf "$staging"' EXIT
/usr/bin/ditto .build/xcode/Build/Products/Release/MacClean.app "$staging/MacClean.app"
/usr/bin/codesign --force --sign - "$staging/MacClean.app"
verify_app "$staging/MacClean.app"
/bin/rm -rf "$MACCLEAN_APP"
/bin/mv "$staging/MacClean.app" "$MACCLEAN_APP"
printf '\nApp: %s\nBuild log: %s/.build/build.log\n' "$MACCLEAN_APP" "$MACCLEAN_ROOT"
