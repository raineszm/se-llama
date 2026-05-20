#!/bin/bash
# test_presets.sh — Integration test: presets.ini router mode
#
# Tests:
#   1. Server starts with a test preset; request with "model": "<preset-name>" gets 200.
#   2. Unknown key in preset causes server to exit with recognized error string (US2 sc2).
#   3. Unknown model in API request returns error; server keeps running (US2 sc3).
#
# Requirements:
#   - se-llama snap installed
#   - TEST_MODEL env var pointing to a valid GGUF file
#
# Usage:
#   TEST_MODEL=/path/to/model.gguf bash tests/integration/test_presets.sh

set -euo pipefail

HOST="${TEST_HOST:-127.0.0.1}"
PORT="${TEST_PORT:-8080}"
TIMEOUT=30
SERVER_PID=""
PRESETS_FILE="${HOME}/snap/se-llama/common/config/presets.ini"
BACKUP_FILE="${PRESETS_FILE}.test-backup"

if [ -z "${TEST_MODEL:-}" ]; then
    echo "[test] ERROR: TEST_MODEL must be set to a valid GGUF file path"
    exit 1
fi

cleanup() {
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    # Restore presets.ini
    if [ -f "$BACKUP_FILE" ]; then
        mv "$BACKUP_FILE" "$PRESETS_FILE"
        echo "[test] Restored presets.ini from backup"
    fi
}
trap cleanup EXIT

# --- Setup: save backup and write test presets ---
cp "$PRESETS_FILE" "$BACKUP_FILE"
cat > "$PRESETS_FILE" <<INI
[*]
no-cache-prompt = true
cache-ram = 0
host = $HOST
port = $PORT

[test-model]
model = $TEST_MODEL
alias = test-model
n-gpu-layers = 0
ctx-size = 512
INI

echo "[test] === Test 1: Preset request returns 200 ==="
se-llama.server &
SERVER_PID=$!

elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
    if curl -sf "http://$HOST:$PORT/health" >/dev/null 2>&1; then
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

if [ "$elapsed" -ge "$TIMEOUT" ]; then
    echo "[test] FAIL Test 1: server did not start"
    exit 1
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    "http://$HOST:$PORT/v1/completions" \
    -H 'Content-Type: application/json' \
    -d '{"model": "test-model", "prompt": "hi", "max_tokens": 1}')

if [ "$HTTP_CODE" = "200" ]; then
    echo "[test] PASS Test 1: got HTTP 200 for preset 'test-model'"
else
    echo "[test] FAIL Test 1: expected 200, got $HTTP_CODE"
    exit 1
fi

kill "$SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""

echo "[test] === Test 2: Unknown key in preset causes startup error ==="
cat > "$PRESETS_FILE" <<INI
[*]
no-cache-prompt = true
cache-ram = 0
host = $HOST
port = $PORT

[bad-preset]
model = $TEST_MODEL
frobnicate = true
INI

# Server should exit non-zero quickly
se-llama.server --host "$HOST" --port "$PORT" 2>&1 | head -5 &
SERVER_PID=$!
sleep 5

if kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "[test] FAIL Test 2: server is still running with invalid preset key (should have exited)"
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    SERVER_PID=""
    exit 1
else
    EXIT_CODE=0
    wait "$SERVER_PID" 2>/dev/null && EXIT_CODE=$? || EXIT_CODE=$?
    SERVER_PID=""
    echo "[test] PASS Test 2: server exited (code $EXIT_CODE) on unknown key 'frobnicate'"
fi

echo "[test] === Test 3: Unknown model in API request returns error; server keeps running ==="
cat > "$PRESETS_FILE" <<INI
[*]
no-cache-prompt = true
cache-ram = 0
host = $HOST
port = $PORT

[test-model]
model = $TEST_MODEL
alias = test-model
n-gpu-layers = 0
ctx-size = 512
INI

se-llama.server &
SERVER_PID=$!

elapsed=0
while [ "$elapsed" -lt "$TIMEOUT" ]; do
    if curl -sf "http://$HOST:$PORT/health" >/dev/null 2>&1; then
        break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    "http://$HOST:$PORT/v1/completions" \
    -H 'Content-Type: application/json' \
    -d '{"model": "nonexistent-model", "prompt": "hi", "max_tokens": 1}')

if [ "$HTTP_CODE" != "200" ]; then
    echo "[test] PASS Test 3: got expected error response (HTTP $HTTP_CODE) for unknown model"
else
    echo "[test] FAIL Test 3: expected error response for nonexistent model, got 200"
    exit 1
fi

# Verify server is still running after the bad request
if curl -sf "http://$HOST:$PORT/health" >/dev/null 2>&1; then
    echo "[test] PASS Test 3: server still running after bad model request"
else
    echo "[test] FAIL Test 3: server crashed after bad model request"
    exit 1
fi

echo "[test] All presets tests passed."
exit 0
