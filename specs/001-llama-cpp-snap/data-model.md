# Data Model: llama.cpp Snap Package

**Branch**: `001-llama-cpp-snap`
**Date**: 2026-05-20

This document defines the key entities, their fields, relationships, state transitions,
and validation rules for the `se-llama` snap.

---

## Entities

### 1. Snap Package (`se-llama`)

The installable unit. Contains the built binaries, default config, and wrapper scripts.

| Field | Type | Notes |
|---|---|---|
| `name` | string | `se-llama` (working name; store name TBD) |
| `version` | string | Tracks upstream llama.cpp git tag/commit |
| `base` | string | `core24` (Ubuntu 24.04 LTS runtime) |
| `confinement` | enum | `strict` (required; `devmode` only during development) |
| `grade` | enum | `devel` during build-out; `stable` before store publish |
| `build-base` | string | `core24` |

**Validation rules**:
- `confinement` MUST be `strict` in any published release.
- `version` MUST be traceable to an upstream llama.cpp commit or tag.

---

### 2. GGUF Model File

A quantized LLM model file placed by the user in the snap model directory. The snap does
not bundle or download models.

| Field | Type | Notes |
|---|---|---|
| `path` | filepath | Absolute path; MUST be under `$SNAP_USER_COMMON/models/` |
| `filename` | string | e.g., `phi-3-mini-q4.gguf` |
| `size_bytes` | int64 | Validated at listing time |
| `magic` | bytes[4] | MUST equal `GGUF` (0x47 0x47 0x55 0x46) |
| `version` | uint32 | GGUF format version (1, 2, or 3) |
| `architecture` | string | Extracted from GGUF metadata (e.g., `llama`, `phi3`) |
| `quantization` | string | Extracted from GGUF metadata (e.g., `Q4_K_M`) |
| `context_length` | uint32 | Trained context length from metadata |

**Validation rules** (applied by `se-llama.models validate`):
- Magic bytes MUST be `GGUF`; any other value → "Not a valid GGUF file".
- File MUST NOT be zero-length.
- File MUST be readable by the snap process (permission check).
- `architecture` field SHOULD be present; if absent, warn but do not block.

---

### 3. Preset

A named model configuration defined as an INI section in `presets.ini`. Passed to
llama-server via `--models-preset <path>` for native parsing in router mode.

| Field | Type | Notes |
|---|---|---|
| `name` | string | INI section header (e.g., `phi3-mini`, `phi3-cpu`) |
| `model` | filepath | Path to the GGUF model file for this preset |
| `alias` | string | API-visible model name matched against request `"model"` field |
| `n-gpu-layers` | int | Layers to offload to GPU; `0` = CPU, `99` = all |
| `ctx-size` | int | Context window tokens; `0` = use model metadata default |
| `no-cache-prompt` | bool | Disable cross-request KV accumulation |
| `cache-ram` | int (MiB) | In-memory cache size; `0` = disabled |
| `no-mmap` | bool | Disable memory-mapping of model weights |
| `host` | string | Bind address (default `127.0.0.1`) |
| `port` | int | Listen port (default `8080`) |

Special section `[*]` sets global defaults applied to all presets.

**Selection mechanism**: Clients select a preset per-request by setting the `"model"`
field in their API call to the preset's `alias` (or `name` if no alias is set). There
is no startup-time preset selection flag.

**Validation rules** (enforced by llama-server natively at startup):
- Unknown keys cause a **fatal startup error** — no pass-through.
- Missing preset file → fatal error.
- Malformed INI → fatal error.
- Preset not found at request time → API error response (server keeps running).
- `slot-save-path` MUST NOT appear in the shipped default `presets.ini`.

---

### 4. Server Session

A running instance of `llama-server` started via `se-llama.server`.

| Field | Type | Notes |
|---|---|---|
| `pid` | int | OS process ID of the llama-server process |
| `model_path` | filepath | GGUF model file currently loaded |
| `preset_name` | string | Name of the preset applied at startup |
| `host` | string | Effective bind address |
| `port` | int | Effective listen port |
| `status` | enum | `starting` → `ready` → `stopped` / `error` |
| `gpu_backend` | string | Detected backend: `Vulkan`, `CPU`, `CUDA`, `ROCm` |
| `log_path` | filepath | `$SNAP_USER_DATA/logs/server-<timestamp>.log` |

**State transitions**:
```
[not running] → starting → ready → stopped
                         ↘ error
```

- `starting`: Process launched, `/health` not yet responding.
- `ready`: `/health` returns `{"status":"ok"}`.
- `stopped`: Process exited cleanly (exit code 0).
- `error`: Process exited with non-zero code, or `/health` check timed out.

**Validation rules**:
- At `starting` → `ready` transition: `/health` MUST respond within 30 seconds.
- Only one server session SHOULD run at a time (enforced by pidfile at
  `$SNAP_USER_COMMON/run/llama-server.pid`).

---

### 5. Snap Data Directories

All filesystem paths the snap reads from or writes to.

| Variable | Typical path | Contents | Persists across refresh |
|---|---|---|---|
| `$SNAP` | `/snap/se-llama/<rev>/` | Read-only snap content (binaries, default config) | N/A |
| `$SNAP_USER_COMMON` | `~/snap/se-llama/common/` | Models, config, pidfile | Yes |
| `$SNAP_USER_DATA` | `~/snap/se-llama/<rev>/` | Logs (per revision) | Per-revision |

**Sub-paths under `$SNAP_USER_COMMON`**:
- `models/` — GGUF model files
- `config/presets.ini` — user-editable preset configuration
- `run/llama-server.pid` — pidfile for single-instance guard

**Sub-paths under `$SNAP_USER_DATA`**:
- `logs/` — server log files

**Paths the snap MUST NOT write to**:
- Anywhere under `/etc/`, `/usr/`, `/home/` (outside snap dirs)
- No `--slot-save-path` or `--lookup-cache-dynamic` paths outside the above dirs

---

## Relationships

```
Snap Package
  ├── contains → Wrapper Scripts (run-server, manage-models)
  ├── contains → Default Config ($SNAP/etc/se-llama/default-presets.ini)
  └── manages →  Snap Data Directories

User
  ├── places → GGUF Model File (in $SNAP_USER_COMMON/models/)
  ├── edits →  Preset (in $SNAP_USER_COMMON/config/presets.ini)
  └── starts → Server Session (via se-llama.server --model <path> [--preset <name>])

Server Session
  ├── loads →  GGUF Model File
  ├── applies → Preset
  └── writes → Logs (in $SNAP_USER_DATA/logs/)
```
