#!/bin/bash
# test_snap_lint.sh — Build snap and run snap lint, assert exit 0
#
# Validates SC-006: snap lint passes with no errors.
#
# Requirements:
#   - snapcraft installed
#   - snap (snapd) installed
#   - Run from repository root
#
# Usage:
#   bash tests/lint/test_snap_lint.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "[test] Building snap with snapcraft..."
cd "$REPO_ROOT"
snapcraft --destructive-mode 2>&1

SNAP_FILE=$(ls ./*.snap 2>/dev/null | head -1)
if [ -z "$SNAP_FILE" ]; then
    echo "[test] FAIL: no .snap file produced by snapcraft"
    exit 1
fi

echo "[test] Running snap lint on $SNAP_FILE..."
snap lint "$SNAP_FILE"
LINT_EXIT=$?

if [ "$LINT_EXIT" -eq 0 ]; then
    echo "[test] PASS: snap lint exited 0 — no errors"
    exit 0
else
    echo "[test] FAIL: snap lint exited $LINT_EXIT"
    exit "$LINT_EXIT"
fi
