#!/bin/bash
# Preserve the command's exit code and surface useful errors in the Actions UI.
set -uo pipefail
if [[ $# -lt 2 ]]; then
    printf 'Usage: %s TITLE COMMAND [ARG…]\n' "$0" >&2
    exit 2
fi
title="$1"
shift
log=$(mktemp "${TMPDIR:-/tmp}/MacClean-ci.XXXXXX")
trap 'rm -f "$log"' EXIT
"$@" 2>&1 | tee "$log"
result=${PIPESTATUS[0]}
if [[ "$result" -ne 0 ]]; then
    lines=$(LC_ALL=C /usr/bin/grep -Ei 'error:|failed|fatal error|exception' "$log" | tail -n 40)
    [[ -n "$lines" ]] || lines=$(tail -n 40 "$log")
    lines=${lines//'%'/'%25'}
    lines=${lines//$'\r'/'%0D'}
    lines=${lines//$'\n'/'%0A'}
    title=${title//'%'/'%25'}
    title=${title//$'\r'/'%0D'}
    title=${title//$'\n'/'%0A'}
    title=${title//':'/'%3A'}
    title=${title//','/'%2C'}
    printf '::error title=%s::%s\n' "$title" "$lines"
fi
exit "$result"
