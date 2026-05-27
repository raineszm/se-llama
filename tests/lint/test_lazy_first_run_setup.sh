#!/bin/bash
# test_lazy_first_run_setup.sh — Verify wrappers seed first-run config without hooks.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

SNAP_ROOT="$TMPDIR/snap"
USER_COMMON="$TMPDIR/user-common"
USER_DATA="$TMPDIR/user-data"
OPENCODE_CONFIG="$TMPDIR/opencode.jsonc"

mkdir -p "$SNAP_ROOT/usr/bin" "$SNAP_ROOT/libexec"
cp "$REPO_ROOT/snap/local/libexec/update_models.py" "$SNAP_ROOT/libexec/update_models.py"
cp "$REPO_ROOT/snap/local/libexec/generate_presets.py" "$SNAP_ROOT/libexec/generate_presets.py"

printf '#!/bin/sh\nexit 0\n' > "$SNAP_ROOT/usr/bin/llama-server"
chmod +x "$SNAP_ROOT/usr/bin/llama-server"

SNAP="$SNAP_ROOT" \
SNAP_USER_COMMON="$USER_COMMON" \
SNAP_USER_DATA="$USER_DATA" \
	"$REPO_ROOT/snap/local/bin/run-server"

if [ ! -f "$USER_COMMON/config/presets.ini" ]; then
	echo "[test] FAIL: run-server did not seed presets.ini"
	exit 1
fi

if [ ! -d "$USER_COMMON/models" ] || [ ! -d "$USER_COMMON/run" ] || [ ! -d "$USER_DATA/logs" ]; then
	echo "[test] FAIL: run-server did not create expected data directories"
	exit 1
fi

rm -f "$USER_COMMON/config/presets.ini"

SNAP="$SNAP_ROOT" \
SNAP_USER_COMMON="$USER_COMMON" \
SNAP_USER_DATA="$USER_DATA" \
	"$REPO_ROOT/snap/local/bin/update-models" --opencode-config "$OPENCODE_CONFIG"

if [ ! -f "$USER_COMMON/config/presets.ini" ]; then
	echo "[test] FAIL: update-models did not seed presets.ini"
	exit 1
fi

echo "[test] PASS: wrappers perform lazy first-run setup"
