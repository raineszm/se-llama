#!/bin/bash
# test_no_install_hook.sh — Assert se-llama has no install hook.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

if [ -e snap/local/hooks/install ]; then
	echo "[test] FAIL: install hook should not exist; first-run setup belongs in run-server"
	exit 1
fi

if grep -q 'hooks/install' snap/snapcraft.yaml; then
	echo "[test] FAIL: snapcraft.yaml should not stage an install hook"
	exit 1
fi

echo "[test] PASS: no install hook is packaged"
