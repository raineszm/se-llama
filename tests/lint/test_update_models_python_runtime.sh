#!/bin/bash
# test_update_models_python_runtime.sh — Verify update-models has a full Python runtime.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SNAPCRAFT="$REPO_ROOT/snap/snapcraft.yaml"
WRAPPER="$REPO_ROOT/snap/local/bin/update-models"

if grep -q 'exec "$SNAP/usr/bin/python3"' "$WRAPPER"; then
	echo "[test] FAIL: update-models must not assume python3 exists at \$SNAP/usr/bin/python3"
	exit 1
fi

if ! grep -q 'exec python3 "$SNAP/libexec/update_models.py"' "$WRAPPER"; then
	echo "[test] FAIL: update-models must execute the Python script with python3 from PATH"
	exit 1
fi

if awk '
	/^  local-files:/ { in_part = 1; next }
	in_part && /^  [[:alnum:]_-]+:/ { in_part = 0 }
	in_part && /^[[:space:]]+- python3$/ { found = 1 }
	END { exit found ? 0 : 1 }
' "$SNAPCRAFT"; then
	echo "[test] FAIL: local-files should only dump local assets; stage python3 in update-models-runtime"
	exit 1
fi

if ! awk '
	/^  update-models-runtime:/ { in_part = 1; next }
	in_part && /^  [[:alnum:]_-]+:/ { in_part = 0 }
	in_part && /^[[:space:]]+plugin: nil$/ { has_plugin = 1 }
	in_part && /^[[:space:]]+- python3$/ { has_python = 1 }
	END { exit has_plugin && has_python ? 0 : 1 }
' "$SNAPCRAFT"; then
	echo "[test] FAIL: update-models-runtime must stage python3 with plugin: nil"
	exit 1
fi

if awk '
	/^  update-models-runtime:/ { in_part = 1; next }
	in_part && /^  [[:alnum:]_-]+:/ { in_part = 0 }
	in_part && /^[[:space:]]+- python3-minimal$/ { found = 1 }
	END { exit found ? 0 : 1 }
' "$SNAPCRAFT"; then
	echo "[test] FAIL: python3-minimal does not provide enough stdlib for update_models.py"
	exit 1
fi

echo "[test] PASS: update-models stages a full snap-provided Python runtime"
