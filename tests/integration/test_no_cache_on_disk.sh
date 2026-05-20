#!/bin/bash
# test_no_cache_on_disk.sh — Integration test: no cache files written after inference + stop
#
# Validates SC-003: No KV cache or inference data written to disk in default config.
#
# Requirements:
#   - se-llama snap installed
#   - At least one GGUF model configured in presets.ini OR TEST_MODEL env var set
#
# Usage:
#   bash tests/integration/test_no_cache_on_disk.sh
#   TEST_MODEL=/path/to/model.gguf bash tests/integration/test_no_cache_on_disk.sh

set -euo pipefail

HOST="${TEST_HOST:-127.0.0.1}"
PORT="${TEST_PORT:-8080}"
TIMEOUT=30
SERVER_PID=""
SNAP_USER_COMMON="${HOME}/snap/se-llama/common"

cleanup() {
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "[test] Stopping server (pid $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "[test] Starting se-llama.server..."
if [ -n "${TEST_MODEL:-}" ]; then
    se-llama.server --model "$TEST_MODEL" --host "$HOST" --port "$PORT" &
else
    se-llama.server --host "$HOST" --port "$PORT" &
fi
SERVER_PID=$!

echo "[test] Waiting for server to be ready..."
elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
    if curl -sf "http://$HOST:$PORT/health" >/dev/null 2>&1; then
        echo "[test] Server is ready."
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

if [ "$elapsed" -ge "$TIMEOUT" ]; then
    echo "[test] FAIL: server did not become ready within ${TIMEOUT}s"
    exit 1
fi

echo "[test] Running inference request..."
curl -sf "http://$HOST:$PORT/v1/completions" \
    -H 'Content-Type: application/json' \
    -d '{"prompt": "Hello", "max_tokens": 5}' \
    -o /dev/null || echo "[test] Note: inference request failed (expected if no model loaded in router mode)"

echo "[test] Stopping server..."
kill "$SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""

echo "[test] Checking for cache/inference files on disk..."
CACHE_FILES=$(find "$SNAP_USER_COMMON" \
    -name "*.cache" \
    -o -name "*.kv" \
    -o -name "*.tmp" \
    -o -name "*.slot" \
    2>/dev/null | grep -v "^$" || true)

if [ -z "$CACHE_FILES" ]; then
    echo "[test] PASS: no cache/inference files found on disk"
    exit 0
else
    echo "[test] FAIL: found unexpected cache files:"
    echo "$CACHE_FILES"
    exit 1
fi
