# Research: llama.cpp Snap Package

**Branch**: `001-llama-cpp-snap`
**Date**: 2026-05-20
**Status**: Complete — all NEEDS CLARIFICATION items resolved

---

## 1. llama.cpp Build System & CMake Flags

**Decision**: Build with CMake, static linkage, Vulkan backend enabled via `-DGGML_VULKAN=1`.

**Rationale**: llama.cpp uses CMake (≥3.14) as its sole supported build system. Static
linking (`-DBUILD_SHARED_LIBS=OFF`) simplifies snap packaging by eliminating the need to
stage shared libraries from the llama.cpp build. Vulkan is the primary GPU backend for
v1 as it works across AMD, Intel, and NVIDIA via host Vulkan ICDs.

**Key CMake flags**:

| Flag | Value | Reason |
|---|---|---|
| `CMAKE_BUILD_TYPE` | `Release` | Must be explicit; omitting it produces a non-optimized build |
| `CMAKE_INSTALL_PREFIX` | `/usr` | Required for snapcraft cmake plugin on core24; defaults are not on PATH |
| `BUILD_SHARED_LIBS` | `OFF` | Self-contained snap binary; no library staging |
| `GGML_VULKAN` | `1` | Enable Vulkan GPU compute backend |
| `LLAMA_BUILD_SERVER` | `ON` | Build `llama-server` binary |

**Upstream source**: `https://github.com/ggml-org/llama.cpp`

**Future GPU backends (out of scope for v1, architecture must accommodate)**:

- **CUDA**: Add `-DGGML_CUDA=ON -DGGML_NATIVE=OFF` and CUDA Toolkit build environment.
  Requires self-hosted build infra (not Launchpad). Candidate as separate snap variant.
- **ROCm/HIP**: `HIPCXX=... cmake -DGGML_HIP=ON -DGPU_TARGETS=gfx...`. Requires ROCm
  dev packages. Also a self-hosted build. The correct flag is `GGML_HIP`, not `GGML_ROCM`
  (the latter is a deprecated alias that now causes a fatal error).

**Alternatives considered**: Ninja generator for faster parallel builds. Adopted as
`cmake-generator: Ninja` in snapcraft.yaml — no downsides on core24.

---

## 2. Snapcraft CMake Plugin (core24)

**Decision**: Use `plugin: cmake` with `cmake-generator: Ninja`. Set
`CMAKE_INSTALL_PREFIX=/usr` explicitly. List all GPU build deps under `build-packages`.

**Rationale**: The snapcraft `cmake` plugin on core24 does **not** auto-set
`CMAKE_INSTALL_PREFIX`. Without it, binaries land at `/usr/local/bin` inside the stage
dir, which is not on the snap's default `PATH`. Setting it to `/usr` matches the snap
runtime `PATH`.

**Critical `build-packages` for Vulkan**:
- `libvulkan-dev` — Vulkan loader headers and link library
- `glslc` — GLSL → SPIR-V compiler, required by llama.cpp Vulkan shader compilation
- `spirv-headers` — SPIR-V header files; **not** transitively pulled by `libvulkan-dev`
  on Ubuntu 24.04

**`stage-packages` for Vulkan (runtime)**:
- `libvulkan1` — Vulkan loader (runtime); ICDs come from host via `opengl` interface

Do **not** stage vendor ICD packages (e.g., `mesa-vulkan-drivers`). Staging GPU drivers
in the snap would embed stale driver code that mismatches the host kernel at runtime.

---

## 3. Vulkan Access & Snap Interface

**Decision**: Use the `opengl` snapd interface for GPU access.

**Rationale**: There is no dedicated `vulkan` snapd interface. The `opengl` interface
grants access to `/dev/dri/*` (DRM render nodes used by Vulkan on AMD/Intel) and
`/dev/nvidia*` (NVIDIA devices). When connected, snapd injects host Vulkan ICD JSON
paths so `libvulkan1` inside the snap discovers and loads the correct host ICD
automatically. This makes Vulkan work correctly without bundling any GPU vendor code.

**Interfaces required per app**:

| App | Interfaces |
|---|---|
| `se-llama.server` | `network`, `network-bind`, `opengl` |
| `se-llama.update-models` | `home` |

**Alternatives considered**: `custom-device` interface for a tighter allowlist — rejected
as significantly more complex with no meaningful security gain for this use case.

---

## 4. Strict Confinement & AppArmor

**Decision**: Strict confinement with `network` for outbound model downloads performed
by llama-server, `network-bind` for localhost binding, and `opengl` for GPU. Model files
used by the server live in snap-owned data under `$SNAP_USER_COMMON/models/`, which does
not require an additional interface.

**Rationale**: `network-bind` covers all `bind()` syscalls. Limiting to
`127.0.0.1` must be enforced at the application level (`--host 127.0.0.1` flag);
AppArmor does not filter by bind address.

**Model file access strategy**: Use `$SNAP_USER_COMMON/models/` as the canonical model
directory. Users can copy model files there directly, or rely on `hf-repo` presets so
llama-server downloads model artifacts into snap-managed storage.

**Write paths** (no extra interface needed — all within snap data dirs):
- `$SNAP_USER_COMMON/models/` — model storage (persists across refresh)
- `$SNAP_USER_COMMON/config/` — `presets.ini` and runtime config
- `$SNAP_USER_DATA/logs/` — per-version log files
- `/tmp` — scratch (via standard tmpfs; AppArmor allows `owner /tmp/**`)

---

## 5. Disk Cache Suppression

**Decision**: Default snap configuration MUST omit `--slot-save-path` (the only flag
that causes KV cache data to be written to disk). Additionally default to
`--no-cache-prompt` and `--cache-ram 0` for stateless operation.

**Rationale**: By default, llama.cpp **does not write any cache data to disk**. The
only disk-writing cache mechanism is `--slot-save-path`. The snap wrapper must
explicitly **not** set this flag in the default `presets.ini`, and must document that
setting it will cause persistent data to be written to the specified path.

**Flag reference for the default preset**:

| Flag | Effect | Include in default? |
|---|---|---|
| *(omit `--slot-save-path`)* | No KV slot state written to disk | ✅ (by omission) |
| `--no-cache-prompt` | Don't accumulate prompt KV across requests | ✅ yes |
| `--cache-ram 0` | Disable cross-request in-memory slot caching | ✅ yes |
| `--no-mmap` | Read model fully into RAM (no demand-paging) | Optional; set in high-privacy preset |

**Audit implication**: After each server stop, `$SNAP_USER_COMMON` and `$SNAP_USER_DATA`
will contain no inference artifacts. The only writable paths are config files and logs.
This fully satisfies SC-003 and US4 audit requirement.

---

## 6. Snap Data Directory Strategy

**Decision**: Use `$SNAP_USER_COMMON` for both models and config; `$SNAP_USER_DATA` for
logs.

| Path | Contents | Persists across refresh? |
|---|---|---|
| `$SNAP_USER_COMMON/models/` | User-supplied GGUF model files | Yes |
| `$SNAP_USER_COMMON/config/presets.ini` | User-editable config | Yes |
| `$SNAP_USER_DATA/logs/` | llama-server logs (current revision) | Per-revision |
| `/tmp` (or `$XDG_RUNTIME_DIR`) | No snap-initiated scratch; OS clears | N/A |

**Rationale**: Models are potentially many gigabytes; using `$SNAP_USER_COMMON` avoids
duplicating them across revisions during `snap refresh`. Config likewise should survive
upgrades unchanged. Logs are revision-specific and can be lost on `snap revert` without
consequence.

**Multi-user caveat**: `snap remove --purge` only removes data for the invoking user.
For a full data purge on a multi-user system, administrators must manually remove
`~<other-user>/snap/se-llama/` for each affected user. This must be documented in the
data-handling guide (quickstart.md).

---

## 7. Configuration: `--models-preset` (Router Mode)

**Decision**: Use llama-server's native `--models-preset <path>` flag in router mode
(no `--model`). Ship a default `presets.ini` at `$SNAP/etc/se-llama/presets.ini`,
seeded to `$SNAP_USER_COMMON/config/presets.ini` on first run. The wrapper passes
`--models-preset $SNAP_USER_COMMON/config/presets.ini` and `--models-dir
$SNAP_USER_COMMON/models/` to llama-server; no custom INI parsing is needed.

**Rationale**: `--models-preset` is a first-class llama-server feature. It is an INI
file whose sections are named model configurations. The server runs in **router mode**
(no `--model` flag); incoming API requests select a model by the `model` field in the
request body (matched to an INI section name). llama-server handles all INI parsing
natively — no wrapper-side parsing required.

**Important behavioral detail**: Preset selection happens per-request via the `"model"`
field in the OpenAI-compatible API call, NOT via a `--preset` flag at startup. The
wrapper does not need to translate preset names to flags.

**Env var**: `LLAMA_ARG_MODELS_PRESET` (overridden by CLI flag).

**Error behavior** (all fatal at startup):
- File missing → `"preset file does not exist: <path>"`
- Malformed INI → `"failed to parse server config file: <path>"`
- Unrecognized key → `"option '<key>' not recognized in preset '<name>'"`
- Named preset not found at request time → API error response (not a crash)

**Preset INI format** (section = model alias; `[*]` = global defaults):
```ini
; Global defaults applied to all presets
[*]
no-cache-prompt = true
cache-ram = 0
host = 127.0.0.1
port = 8080

[phi3-mini]
model = /home/user/snap/se-llama/common/models/phi-3-mini-q4.gguf
n-gpu-layers = 99
alias = phi3-mini
ctx-size = 4096

[phi3-mini-cpu]
model = /home/user/snap/se-llama/common/models/phi-3-mini-q4.gguf
n-gpu-layers = 0
alias = phi3-mini-cpu
```

**Wrapper responsibility** (simplified — no INI parsing):
1. Ensure `$SNAP_USER_COMMON/config/presets.ini` exists (seed from default if not).
2. Exec `llama-server --models-preset $SNAP_USER_COMMON/config/presets.ini
   --models-dir $SNAP_USER_COMMON/models/ [additional CLI flags...]`.

**Alternatives considered**: Custom wrapper that parses INI and translates to
`LLAMA_ARG_*` env vars — rejected; the native `--models-preset` flag makes this
unnecessary and eliminates a bespoke parser that could diverge from llama-server's
own parsing.

---

## 8. Multiple Snap Apps

**Decision**: Expose two apps: `se-llama.server` (llama-server wrapper) and
`se-llama.update-models` (OpenCode config sync helper).

**Rationale**: Keeping server and config sync as separate snap apps allows different
plug sets — `update-models` needs `home` for a user-selected OpenCode config path, while
the server does not.

**App structure** (snapcraft.yaml `apps:` section):
```yaml
apps:
  server:
    command: bin/run-server
    plugs: [network, network-bind, opengl]
  update-models:
    command: bin/update-models
    plugs: [home]
```

Exposed as `se-llama.server` and `se-llama.update-models`.

---

## 9. FR-008 Clarification: Model Loading

**Decision**: No separate local model listing/validation helper is shipped in v1.

**Rationale**: The server can consume local paths in `$SNAP_USER_COMMON/models/` and can
also use llama.cpp's native `hf-repo` handling. Keeping a separate helper out of v1
avoids another command surface and keeps interface review focused on the server and the
OpenCode sync helper.

**Future scope**: A model helper can be reconsidered after the server workflow is stable.

---

## 10. Snap Name & Store Considerations

**Decision**: Working name `se-llama` used throughout. Final store name to be confirmed
separately (may conflict with existing store registrations).

**Action item**: Run `snapcraft register se-llama` or check store availability before
publishing. The snapcraft.yaml `name:` field must be updated before first `snap upload`.
