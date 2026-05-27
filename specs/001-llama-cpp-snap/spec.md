# Feature Specification: llama.cpp Snap Package

**Feature Branch**: `001-llama-cpp-snap`

**Created**: 2026-05-20

**Status**: Draft

**Input**: User description: "I want to build a snap for llama.cpp. The central goal is
to be able to run local models with a good amount of freedom, but to ensure that llama
is properly configured to not store sensitive data to disk, especially cached prompts.
Because sustaining engineering needs to be able to track where customer data goes and be
sure that it is cleaned up we want the snap to be preconfigured to make this easy. Also
it should be a confined snap so that it has only the permissions it needs. At the same
time, users should have the freedom to download and run the models they want and
configure various generation parameters through either the llama-server cli options or
presets.ini. To ensure latest features we'll want to build from upstream and include at
least the vulkan backend. Future goals will be in to include ROCm and CUDA support."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run a local model safely (Priority: P1)

A support engineer (or developer) installs the snap, places a GGUF model file in the
designated models directory, starts `llama-server`, and interacts with it via the
OpenAI-compatible REST API — with the assurance that no prompt cache or conversation
history is written to persistent storage.

**Why this priority**: This is the core use case. Without it nothing else matters.

**Independent Test**: Install the snap on an Ubuntu 24.04 machine with Vulkan-capable
GPU (or CPU fallback). Download a small GGUF model (e.g., Phi-3 Mini Q4). Run
`llama-server`. Confirm it starts, serves `/v1/completions`, and leaves no cache files
in `$SNAP_USER_DATA` or `/tmp` after stopping.

**Acceptance Scenarios**:

1. **Given** the snap is installed and a GGUF model is in `$SNAP_USER_COMMON/models/`,
   **When** the user runs `se-llama.server --model <model>`,
   **Then** the server starts and responds to `GET /health` with `{"status":"ok"}`.

2. **Given** the server has processed one or more prompt requests,
   **When** the server is stopped and the snap data directories are inspected,
   **Then** no prompt cache files (`.cache`, `.kv`, temp files) exist on disk.

3. **Given** a system without a Vulkan GPU,
   **When** the server starts,
   **Then** it falls back to CPU inference and logs a clear message indicating the
   backend in use.

---

### User Story 2 - Configure generation parameters via presets (Priority: P2)

A user creates or edits a `presets.ini` file in the snap's user config directory to
define named model configurations (model path, GPU layers, context size, caching
behaviour, etc.). The server runs in router mode (`--models-preset`); clients select
which model/configuration to use by setting the `"model"` field in their API request to
a preset name or alias.

**Why this priority**: Enables repeatable, auditable configurations without requiring
users to memorize long CLI flag sequences. Named presets also make it straightforward
to define a "high-privacy" config that disables all caching.

**Independent Test**: Create a `presets.ini` with a `[phi3-mini]` section setting
`n-gpu-layers = 0` and `ctx-size = 2048`. Start the server. Send a request with
`"model": "phi3-mini"`. Confirm via server log that the parameters were applied.

**Acceptance Scenarios**:

1. **Given** a valid `presets.ini` in `$SNAP_USER_COMMON/config/` with a `[phi3-mini]`
   section,
   **When** the server is started and a client sends `{"model": "phi3-mini", ...}`,
   **Then** the server applies the parameters from the `[phi3-mini]` section.

2. **Given** a `presets.ini` with an unknown key `frobnicate = true` in any section,
   **When** the server is started,
   **Then** the server exits with a clear error:
   `"option 'frobnicate' not recognized in preset '<name>'"`.

3. **Given** a client sends `{"model": "nonexistent", ...}`,
   **When** the server is running,
   **Then** the server returns an API error response identifying the unknown model
   (server does not crash).

---

### User Story 3 - Snap confinement limits filesystem access (Priority: P2)

The confined snap reads model files from snap-managed storage and cannot read arbitrary
filesystem locations, limiting blast radius if the inference server is exploited.

**Why this priority**: Safety and data containment are constitutional requirements.
This story validates the confinement is real, not nominal.

**Independent Test**: Attempt to start the server with `--model /etc/passwd`. Confirm
the snap's AppArmor/seccomp profile blocks the read and the server exits with a
permission error.

**Acceptance Scenarios**:

1. **Given** the snap is strictly confined,
   **When** a model path outside snap-managed data is specified,
   **Then** the snap's AppArmor profile denies the open and the server reports the
   denial clearly.

2. **Given** the snap is running,
   **When** the server process attempts to write to a path outside snap data dirs,
   **Then** the write is denied by confinement.

---

### User Story 4 - Data cleanup auditability (Priority: P3)

A support engineer can verify, at any time, that no customer prompt data persists beyond
a session by inspecting a known, bounded set of snap data directories.

**Why this priority**: Sustaining engineering audit requirement. Enables confident
data-retention compliance.

**Independent Test**: After a session, run the provided audit helper or manually inspect
`$SNAP_USER_DATA` and `$SNAP_USER_COMMON`. Confirm no inference artifacts remain.

**Acceptance Scenarios**:

1. **Given** documentation of all paths the snap can write to,
   **When** a support engineer inspects those paths after stopping the server,
   **Then** no prompt cache, KV cache, or conversation logs exist.

2. **Given** a snap removal (`snap remove --purge se-llama`),
   **When** the data directories are checked post-removal,
   **Then** all snap-managed data is gone (snap purge semantics).

---

### Edge Cases

- What happens when the models directory is empty at startup?
- How does the server handle a GGUF file that is corrupted or truncated?
- What if `presets.ini` contains a parameter not recognized by `llama-server`?
- What if Vulkan drivers are installed but the GPU has insufficient VRAM for the model?
- What happens if the snap is started while another instance is already running?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The snap MUST build `llama-server` (and optionally other llama.cpp tools)
  from the upstream llama.cpp source at build time.
- **FR-002**: The snap MUST enable the Vulkan compute backend at build time.
- **FR-003**: The snap MUST disable on-disk prompt caching by default
  (`--no-kv-offload` equivalent or explicit cache path set to a tmpfs/volatile
  location that is cleared on snap stop).
- **FR-004**: The snap MUST use strict confinement with a minimal set of interfaces.
  The server app must not receive broad home-directory access.
- **FR-005**: The snap MUST provide a `presets.ini` mechanism so users can define named
  parameter groups applied at server startup.
- **FR-006**: The snap MUST document all filesystem paths it reads from and writes to.
- **FR-007**: The snap MUST expose `llama-server` as a named snap app
  (`se-llama.server`).
- **FR-008**: The snap SHOULD rely on llama-server's native model loading and Hugging
  Face repository support in v1.
- **FR-009**: The snap build MUST be reproducible from a `snapcraft.yaml` without
  manual steps.
- **FR-010**: The snap MUST pass `snap lint` with no errors in strict confinement mode.
- **FR-011**: Future backends (ROCm, CUDA) MUST be accommodatable by the snap build
  architecture without requiring a full rewrite of `snapcraft.yaml`.

### Key Entities

- **Snap**: The packaged unit. Name TBD (likely `llama-cpp` or `se-llama`).
- **llama-server**: The primary binary; HTTP server exposing OpenAI-compatible API.
- **GGUF model**: A quantized model file placed by the user in the models directory.
- **presets.ini**: User-editable INI file mapping preset names to llama-server flags.
- **Snap data directories**: `$SNAP_USER_COMMON/models/`, `$SNAP_USER_COMMON/config/`,
  `$SNAP_DATA` (system-level), `$SNAP_USER_DATA` (per-user volatile).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `snap install se-llama` (or `--dangerous` for local build) completes
  without error on Ubuntu 24.04.
- **SC-002**: `se-llama.server --model <gguf>` starts and passes `/health` check within
  30 seconds on a machine with ≥8 GB RAM.
- **SC-003**: Zero files matching `*.cache`, `*.kv`, `*.tmp` exist in snap data dirs
  after server stop.
- **SC-004**: `snap connections se-llama` shows only the declared interfaces — no
  unexpected broad permissions.
- **SC-005**: The snap builds from a clean `snapcraft clean && snapcraft` invocation in
  under 30 minutes on a modern workstation.
- **SC-006**: `snap lint se-llama_*.snap` reports zero errors.

## Assumptions

- Target Ubuntu release: 24.04 LTS (core24 base).
- Primary GPU backend for v1: Vulkan (works on AMD, Intel, and NVIDIA via Vulkan layers).
- ROCm and CUDA backends are out of scope for v1 but the build architecture MUST
  accommodate them as future snap variants or build-time flags.
- Models are user-supplied GGUF files; the snap does not bundle or download models.
- The snap name for the store will be confirmed separately; `se-llama` used as working
  name throughout.
- No GUI is required; interaction is via CLI and HTTP API.
- The snap will be built with `snapcraft` on Ubuntu 24.04 using the `core24` base.
