#!/bin/bash
set -euo pipefail

MACCLEAN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
config="$MACCLEAN_ROOT/Config/Version.xcconfig"
version=$(awk '$1 == "MARKETING_VERSION" && $2 == "=" {print $3}' "$config")
build=$(awk '$1 == "CURRENT_PROJECT_VERSION" && $2 == "=" {print $3}' "$config")
if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(\.(0|[1-9][0-9]*))?$ ]] ||
   [[ ! "$build" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Invalid version or build number in %s\n' "$config" >&2
    exit 1
fi

case "${1:-}" in
    '') [[ $# -eq 0 ]] || exit 2; printf '%s\n' "$version" ;;
    --build) [[ $# -eq 1 ]] || exit 2; printf '%s\n' "$build" ;;
    --tag) [[ $# -eq 1 ]] || exit 2; printf 'v%s\n' "$version" ;;
    --check-tag)
        if [[ $# -ne 2 ]]; then
            printf 'Usage: %s --check-tag v<version>\n' "$0" >&2
            exit 2
        fi
        if [[ "$2" != "v$version" ]]; then
            printf 'Tag %s does not match Config/Version.xcconfig (v%s).\n' "$2" "$version" >&2
            exit 1
        fi
        ;;
    *) printf 'Usage: %s [--build | --tag | --check-tag TAG]\n' "$0" >&2; exit 2 ;;
esac
