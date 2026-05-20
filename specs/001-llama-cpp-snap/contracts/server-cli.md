# Contract: se-llama.server CLI Interface

**Type**: CLI command contract
**App**: `se-llama.server`
**Binary**: `$SNAP/bin/llama-server` (via wrapper `$SNAP/bin/run-server`)

---

## Invocation

```
se-llama.server [llama-server-flags...]
```

The wrapper:
1. Seeds `$SNAP_USER_COMMON/config/presets.ini` from the snap default if it does not
   exist.
2. Execs `llama-server` with `--models-preset` and `--models-dir` prepended, followed
   by any flags the user passed.

Effective invocation inside the snap:

```
llama-server \
  --models-preset $SNAP_USER_COMMON/config/presets.ini \
  --models-dir    $SNAP_USER_COMMON/models/ \
  [user-supplied flags...]
```

---

## Operating mode

The snap runs llama-server in **router mode** (no `--model` flag). Models are defined
in `presets.ini` as named sections. Clients select a model by setting the `"model"`
field in their OpenAI-compatible API request to the section name (or alias) from
`presets.ini`.

To run a single specific model without presets, pass `--model <path>` explicitly:

```
se-llama.server --model ~/snap/se-llama/common/models/phi3.gguf
```

This bypasses `presets.ini` for that invocation.

---

## Wrapper-specific behavior (not forwarded to llama-server)

| Behavior | Description |
|---|---|
| Config seeding | If `$SNAP_USER_COMMON/config/presets.ini` does not exist, copy from `$SNAP/etc/se-llama/presets.ini` before exec |

All other flags are forwarded verbatim to `llama-server`. The wrapper adds no
additional parsing or translation.

---

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Server exited cleanly (SIGTERM or graceful shutdown) |
| `1` | llama-server runtime error (model load failure, port conflict, etc.) |
| `1` | Preset file missing or malformed (llama-server exits with error message) |

llama-server exits with a descriptive error on bad preset files — the wrapper does not
intercept these; they propagate directly.

---

## Standard streams

- **stdout**: llama-server log output (JSON lines when `--log-format json` is set)
- **stderr**: Wrapper messages (config seeding notice); llama-server errors
- **stdin**: Not used

---

## Startup readiness

The server is ready when `GET http://<host>:<port>/health` returns HTTP 200:
```json
{"status": "ok"}
```
Poll at 1-second intervals for up to 30 seconds before declaring startup failure.

---

## Model selection (router mode)

Clients specify the model per-request using the OpenAI `model` field:

```bash
curl http://127.0.0.1:8080/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{"model": "phi3-mini", "prompt": "Hello", "max_tokens": 20}'
```

The value `"phi3-mini"` must match a section name or `alias` value in `presets.ini`.
If no match is found, llama-server returns an API error (not a crash).

---

## Data written to disk

| Path | Written when | Cleared when |
|---|---|---|
| `$SNAP_USER_DATA/logs/server-<ts>.log` | On start | `snap refresh` (new revision) |
| `$SNAP_USER_COMMON/run/llama-server.pid` | On start | On clean stop |
| `$SNAP_USER_COMMON/config/presets.ini` | On first start (seeded from default) | Never automatically |

**No KV cache, prompt cache, or inference data is written to disk** when `presets.ini`
does not set `slot-save-path`. The default shipped `presets.ini` MUST NOT set
`slot-save-path`.
