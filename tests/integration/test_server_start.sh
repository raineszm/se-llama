#!/bin/bash
# test_server_start.sh — Integration test: se-llama.server starts and passes /health
#
# Requirements:
#   - se-llama snap installed
#   - At least one GGUF model in ~/snap/se-llama/common/models/ and configured in presets.ini
#     OR provide a model path via TEST_MODEL env var
#
# Usage:
#   bash tests/integration/test_server_start.sh
#   TEST_MODEL=/path/to/model.gguf bash tests/integration/test_server_start.sh

set -euo pipefail

HOST="${TEST_HOST:-127.0.0.1}"
PORT="${TEST_PORT:-8080}"
TIMEOUT=30
SERVER_PID=""

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

echo "[test] Polling http://$HOST:$PORT/health (timeout: ${TIMEOUT}s)..."
elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
    if curl -sf "http://$HOST:$PORT/health" >/dev/null 2>&1; then
        response=$(curl -sf "http://$HOST:$PORT/health")
        echo "[test] Health response: $response"
        if echo "$response" | grep -q '"status".*"ok"'; then
            echo "[test] PASS: server is healthy"
            exit 0
        fi
    fi
    sleep 1
    elapsed=$((elapsed + 1))
    echo "[test] ... waiting ($elapsed/${TIMEOUT}s)"
done

echo "[test] FAIL: server did not become healthy within ${TIMEOUT}s"
exit 1
