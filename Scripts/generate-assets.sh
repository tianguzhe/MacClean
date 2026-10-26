#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/vector-tools
if [[ ! -d .build/vector-tools/node_modules/svg-to-pdfkit ]]; then
    cp Scripts/vector-requirements.json .build/vector-tools/package.json
    npm install --prefix .build/vector-tools --ignore-scripts --no-audit --no-fund
fi
swift -module-cache-path .build/icon-module-cache Scripts/generate-icon.swift
NODE_PATH="$PWD/.build/vector-tools/node_modules" node Scripts/generate-brand-assets.cjs
swift -module-cache-path .build/icon-module-cache Scripts/generate-dmg-background.swift
