#!/bin/bash
# Integration tests for snap/local/bin/generate-presets.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

export SNAP="$REPO_ROOT/snap/local"
export SNAP_USER_COMMON="$TMPDIR/common"

COMMAND="$REPO_ROOT/snap/local/bin/generate-presets"

echo "[test] first run creates presets.ini"
OUTPUT="$($COMMAND)"
PRESETS="$SNAP_USER_COMMON/config/presets.ini"
test -f "$PRESETS"
grep -q "Created presets.ini: $PRESETS" <<<"$OUTPUT"
grep -q "Selected profile:" <<<"$OUTPUT"
grep -q "Next: run se-llama.server" <<<"$OUTPUT"
grep -q "Warning: first se-llama.server start may download" <<<"$OUTPUT"
grep -q "llama-server handles downloads at runtime" <<<"$OUTPUT"
grep -q "\[low\]\|\[balanced\]\|\[large\]" "$PRESETS"
grep -q "\[low\]" "$PRESETS"
grep -q "\[balanced\]" "$PRESETS"
grep -q "\[large\]" "$PRESETS"
if grep -q "slot-save-path" "$PRESETS"; then
    echo "[test] FAIL: generated presets include slot-save-path"
    exit 1
fi

echo "[test] existing presets.ini is preserved"
printf 'custom = true\n' >"$PRESETS"
OUTPUT="$($COMMAND)"
grep -q "presets.ini already exists: $PRESETS" <<<"$OUTPUT"
grep -q "No changes made" <<<"$OUTPUT"
test "$(cat "$PRESETS")" = "custom = true"

echo "[test] force replaces and creates backup"
OUTPUT="$($COMMAND --force --profile low)"
grep -q "Replaced presets.ini: $PRESETS" <<<"$OUTPUT"
test -n "$(ls "$SNAP_USER_COMMON/config"/presets.ini.backup-* 2>/dev/null)"
grep -q "\[low\]" "$PRESETS"

echo "[test] dry run prints generated content only"
rm -f "$PRESETS" "$SNAP_USER_COMMON"/config/presets.ini.backup-*
OUTPUT="$($COMMAND --dry-run --profile large)"
grep -q "Preview presets.ini" <<<"$OUTPUT"
grep -q "\[large\]" <<<"$OUTPUT"
test ! -e "$PRESETS"

echo "[test] PASS: generate-presets integration"
