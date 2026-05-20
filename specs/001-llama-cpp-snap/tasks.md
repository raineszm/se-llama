---
description: "Task list for llama.cpp snap package implementation"
---

# Tasks: llama.cpp Snap Package

**Input**: Design documents from `specs/001-llama-cpp-snap/`

**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: Not explicitly requested — integration test scripts are included as
implementation tasks (they are the verification mechanism for each story, not
TDD stubs).

**Organization**: Tasks grouped by user story to enable independent implementation
and testing of each story.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository structure, snapcraft scaffolding, build environment.

- [X] T001 Rename `snap/snapcraft.yaml` metadata: set `name: se-llama`, `base: core24`, `confinement: strict`, `grade: devel`, `summary`, `description` in `snap/snapcraft.yaml`
- [X] T002 Create directory structure `snap/local/bin/`, `snap/local/etc/se-llama/`, `snap/local/hooks/`, `tests/integration/`, `tests/lint/` per plan.md
- [X] T003 [P] Add upstream llama.cpp source part skeleton to `snap/snapcraft.yaml`: `source: https://github.com/ggml-org/llama.cpp`, `plugin: cmake`, `cmake-generator: Ninja`, placeholder `cmake-parameters` list
- [X] T004 [P] Add `build-packages` to the llama.cpp part in `snap/snapcraft.yaml`: `cmake`, `ninja-build`, `libvulkan-dev`, `glslc`, `spirv-headers`, `g++`, `pkg-config`
- [X] T005 [P] Add `stage-packages` to the llama.cpp part in `snap/snapcraft.yaml`: `libvulkan1`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core snap build must be working before any story can be verified on a
real system. All user stories depend on a buildable, installable snap.

**⚠️ CRITICAL**: No user story work can be fully validated until this phase is complete.

- [X] T006 Fill CMake parameters in the llama.cpp part in `snap/snapcraft.yaml`: `-DCMAKE_BUILD_TYPE=Release`, `-DCMAKE_INSTALL_PREFIX=/usr`, `-DBUILD_SHARED_LIBS=OFF`, `-DGGML_VULKAN=1`, `-DLLAMA_BUILD_SERVER=ON` — see research.md §1
- [X] T007 Add `prime` filter to the llama.cpp part in `snap/snapcraft.yaml` to include only `usr/bin/llama-server` and `usr/bin/llama-*` (exclude build artifacts and unused tools)
- [X] T008 Add `apps:` section to `snap/snapcraft.yaml` with `server` app: `command: bin/run-server`, `plugs: [network-bind, opengl, personal-files]`
- [X] T009 Add `models` app to the `apps:` section in `snap/snapcraft.yaml`: `command: bin/manage-models`, `plugs: [personal-files]`
- [X] T010 Add `plugs:` top-level section to `snap/snapcraft.yaml` declaring `personal-files` plug with `read` path `$SNAP_USER_COMMON/models`
- [X] T011 Add a `dump` or `local-files` part to `snap/snapcraft.yaml` to stage files from `snap/local/` into the snap root
- [ ] T012 Verify snap builds without error: run `snapcraft --destructive-mode` or in a VM/LXD container and fix any build errors in `snap/snapcraft.yaml`

**Checkpoint**: `snapcraft` completes and produces `se-llama_*.snap`. Install with
`sudo snap install se-llama_*.snap --dangerous` before proceeding.

---

## Phase 3: User Story 1 - Run a Local Model Safely (Priority: P1) 🎯 MVP

**Goal**: A user can start `se-llama.server` with a GGUF model, get a `/health` 200
response, run an inference, stop the server, and confirm zero cache files remain on disk.

**Independent Test**: `bash tests/integration/test_server_start.sh` and
`bash tests/integration/test_no_cache_on_disk.sh` both pass.

### Implementation for User Story 1

- [X] T013 [US1] Write `snap/local/bin/run-server` wrapper script: check if `$SNAP_USER_COMMON/config/presets.ini` exists; if not, copy `$SNAP/etc/se-llama/presets.ini`; exec `llama-server --models-preset $SNAP_USER_COMMON/config/presets.ini --models-dir $SNAP_USER_COMMON/models/ "$@"` — see contracts/server-cli.md
- [X] T014 [US1] Make `snap/local/bin/run-server` executable (`chmod +x`) and confirm the `dump` part in `snap/snapcraft.yaml` stages it to `bin/run-server` inside the snap
- [X] T015 [US1] Write `snap/local/hooks/install` hook script: `mkdir -p $SNAP_USER_COMMON/config $SNAP_USER_COMMON/models $SNAP_USER_COMMON/run`; copy default presets if not present — see data-model.md §Snap Data Directories
- [X] T016 [US1] Write `snap/local/etc/se-llama/presets.ini` default config: `[*]` section with `no-cache-prompt = true`, `cache-ram = 0`, `host = 127.0.0.1`, `port = 8080`; add example `[phi3-mini]` section (path commented out) — see contracts/presets-ini.md
- [ ] T017 [US1] Rebuild snap, install `--dangerous`, place a small GGUF model in `~/snap/se-llama/common/models/`, add it to presets.ini, start `se-llama.server`, confirm `curl http://127.0.0.1:8080/health` returns `{"status":"ok"}`
- [X] T018 [US1] Write `tests/integration/test_server_start.sh`: start server, poll `/health` up to 30 s, assert HTTP 200, stop server, assert exit 0
- [X] T019 [US1] Write `tests/integration/test_no_cache_on_disk.sh`: start server, run one `/v1/completions` request, stop server, `find ~/snap/se-llama/ -name "*.cache" -o -name "*.kv" -o -name "*.tmp"`, assert no results — validates SC-003
- [ ] T020 [US1] Verify CPU fallback: temporarily set `n-gpu-layers = 0` in presets.ini, start server, confirm it starts and logs CPU backend, restore setting

**Checkpoint**: US1 fully functional — server starts, serves inference, leaves no cache
files on disk after stop.

---

## Phase 4: User Story 2 - Configure via Presets (Priority: P2)

**Goal**: A user edits `presets.ini` to define named model configurations; the server
applies them per-request via the `"model"` field in the API call.

**Independent Test**: `bash tests/integration/test_presets.sh` passes — server started,
request sent with `"model": "phi3-mini"`, response received, server log confirms the
preset parameters were used.

### Implementation for User Story 2

- [X] T021 [US2] Extend `snap/local/etc/se-llama/presets.ini` with a `[phi3-mini-cpu]` section (CPU-only preset) demonstrating the multi-preset pattern — see contracts/presets-ini.md §Format
- [X] T022 [US2] Update `quickstart.md` presets section to use correct model paths using `$HOME/snap/se-llama/common/models/` (absolute paths required in presets.ini `model =` key) — see contracts/presets-ini.md
- [X] T023 [US2] Write `tests/integration/test_presets.sh`: add a test preset to presets.ini, start server, send `{"model": "<preset-name>", "prompt": "hello", "max_tokens": 1}`, assert 200 response, assert server log shows correct model loaded
- [X] T024 [US2] Write a negative test in `tests/integration/test_presets.sh`: add an unknown key (`frobnicate = true`) to a test preset section, start server, assert it exits with the recognized error string — validates spec US2 scenario 2
- [ ] T025 [US2] Verify unknown-model API behaviour: start server with valid presets.ini, send `{"model": "nonexistent", ...}`, assert API returns an error response and server keeps running — validates spec US2 scenario 3

**Checkpoint**: US1 and US2 both independently functional and testable.

---

## Phase 5: User Story 3 - Confinement Validation (Priority: P2)

**Goal**: Strict confinement is real — AppArmor denies access to paths outside snap
data dirs; `snap lint` reports zero errors.

**Independent Test**: `bash tests/lint/test_snap_lint.sh` exits 0; `bash tests/integration/test_confinement.sh` confirms AppArmor denial for out-of-bounds path.

### Implementation for User Story 3

- [X] T026 [US3] Run `snap lint se-llama_*.snap` and fix all reported errors in `snap/snapcraft.yaml` (common issues: missing `plugs` declarations, invalid `apps` keys, grade/confinement mismatches)
- [ ] T027 [US3] Connect interfaces on the test machine and verify with `snap connections se-llama`: only `network-bind`, `opengl`, `personal-files` should appear — validates SC-004
- [X] T028 [US3] Write `tests/lint/test_snap_lint.sh`: run `snapcraft` then `snap lint se-llama_*.snap`, assert exit code 0 — validates SC-006
- [X] T029 [US3] Write `tests/integration/test_confinement.sh`: attempt `se-llama.server --model /etc/passwd`, assert the process exits with a permission/AppArmor error (not a segfault or silent success) — validates spec US3 scenario 1
- [ ] T030 [US3] Verify write confinement: while server is running, attempt `cp /dev/null ~/snap/se-llama/../../other-path` from inside the snap namespace (or check `/proc/<pid>/root` access), confirm writes outside snap dirs are denied — validates spec US3 scenario 2
- [ ] T031 [US3] Set `confinement: strict` and `grade: stable` in `snap/snapcraft.yaml`, rebuild, re-run `snap lint`, confirm still passes

**Checkpoint**: `snap lint` passes, confinement tests pass, SC-004 and SC-006 satisfied.

---

## Phase 6: User Story 4 - Data Cleanup Auditability (Priority: P3)

**Goal**: A support engineer can enumerate all paths the snap writes to and confirm
they are empty of inference data after a session.

**Independent Test**: After running a session and stopping the server, the audit
command in `quickstart.md` finds zero cache/inference files.

### Implementation for User Story 4

- [X] T032 [US4] Write `snap/local/bin/manage-models` shell script implementing `list`, `validate`, and `info` subcommands per `contracts/models-cli.md` — reads from `$SNAP_USER_COMMON/models/`, validates GGUF magic bytes, outputs table or JSON
- [X] T033 [US4] Make `snap/local/bin/manage-models` executable and confirm the `dump` part stages it to `bin/manage-models` inside the snap
- [ ] T034 [US4] Test `se-llama.models list` with an empty models directory — confirm it prints the "directory not found" guidance message and exits 0 — validates contracts/models-cli.md edge case
- [ ] T035 [US4] Test `se-llama.models validate <valid-gguf>` — confirm it prints valid result; test with a non-GGUF file (e.g., a text file) — confirm it prints the invalid magic error
- [ ] T036 [US4] Test `se-llama.models info <gguf>` — confirm metadata fields are printed (architecture, quantization, context length)
- [ ] T037 [US4] Verify the audit procedure from `quickstart.md` §Data audit: after a full session, run `find ~/snap/se-llama/ -name "*.cache" -o -name "*.kv" -o -name "*.tmp"`, confirm empty — validates SC-003 and spec US4 scenario 1
- [ ] T038 [US4] Verify `snap remove --purge se-llama` removes all data: install snap, run a session, remove with `--purge`, confirm `~/snap/se-llama/` does not exist — validates spec US4 scenario 2

**Checkpoint**: All four user stories independently functional and verified.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements spanning all stories; final quality gates.

- [X] T039 [P] Update `snap/snapcraft.yaml` `description:` field with accurate snap store description referencing Vulkan backend, presets.ini, and data privacy defaults
- [X] T040 [P] Add `snap/snapcraft.yaml` comment block at the top documenting how to add ROCm/CUDA backends (flag substitution: replace `-DGGML_VULKAN=1` with `-DGGML_HIP=ON` or `-DGGML_CUDA=ON`) — satisfies FR-011
- [X] T041 [P] Add `layout:` section to `snap/snapcraft.yaml` if needed to expose `/usr/share/vulkan` ICD paths from the host into the snap namespace (required on some systems for Vulkan ICD discovery)
- [X] T042 [P] Update `snap/snapcraft.yaml` `version:` to use `adopt-info` from the llama.cpp part git tag (snapcraft `snapcraftctl set-version` in `override-pull`) so the snap version tracks upstream automatically
- [X] T043 Update complexity tracking row in `specs/001-llama-cpp-snap/plan.md` — remove stale "wrapper INI → env vars" entry, replace with accurate "minimal wrapper seeds config and prepends --models-preset"
- [ ] T044 Run full integration test suite: `bash tests/lint/test_snap_lint.sh`, `bash tests/integration/test_server_start.sh`, `bash tests/integration/test_no_cache_on_disk.sh`, `bash tests/integration/test_presets.sh`, `bash tests/integration/test_confinement.sh` — all must exit 0
- [ ] T045 Run `snapcraft clean && snapcraft` from a clean state, confirm build completes in ≤30 minutes — validates SC-005

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1. BLOCKS all user stories — snap must
  build and install before any story can be verified on a real system.
- **US1 (Phase 3)**: Depends on Phase 2. No story dependencies.
- **US2 (Phase 4)**: Depends on Phase 2. Independent of US1 at the code level (both
  use the same wrapper); can start in parallel with US1 after Phase 2.
- **US3 (Phase 5)**: Depends on Phase 2. Can start in parallel with US1/US2 — lint
  and confinement are independent of preset/model features.
- **US4 (Phase 6)**: Depends on Phase 2. `manage-models` binary is independent;
  audit procedure depends on a working server (US1).
- **Polish (Phase 7)**: Depends on all user stories being complete.

### Within Each User Story

- Wrapper/script files must exist before snap rebuild
- Snap rebuild must complete before integration tests can run
- Tests must be written before they can be executed (but tests are not stubs — write
  and run them in the same task)

### Parallel Opportunities

All `[P]`-marked tasks within a phase can run simultaneously:
- T003, T004, T005 (Phase 1 snap part setup)
- T039, T040, T041, T042 (Phase 7 polish)
- US2 (Phase 4) can begin in parallel with US1 (Phase 3) after Phase 2 completes
- US3 lint work (T026–T028) can run in parallel with US1/US2 story work

---

## Parallel Example: Phase 3 + Phase 5 (after Phase 2 complete)

```bash
# Can run in parallel after Foundational phase:

# Agent A: User Story 1
Task: "Write snap/local/bin/run-server wrapper (T013)"
Task: "Write snap/local/hooks/install hook (T015)"
Task: "Write snap/local/etc/se-llama/presets.ini (T016)"

# Agent B: User Story 3 (lint — no binary dependency)
Task: "Run snap lint and fix errors (T026)"
Task: "Write tests/lint/test_snap_lint.sh (T028)"
Task: "Write tests/integration/test_confinement.sh (T029)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational — snap builds and installs
3. Complete Phase 3: US1 — server starts, serves inference, no cache on disk
4. **STOP and VALIDATE**: `test_server_start.sh` and `test_no_cache_on_disk.sh` pass
5. This is a shippable `grade: devel` snap demonstrating the core privacy guarantee

### Incremental Delivery

1. Setup + Foundational → snap builds
2. US1 → working server with cache-free defaults → MVP
3. US2 → presets router mode functional
4. US3 → confinement verified, `snap lint` passes
5. US4 → `se-llama.models` functional, audit procedure documented and verified
6. Polish → store-ready snap

### Parallel Team Strategy

With two engineers:
- Engineer A: US1 (wrapper, hooks, default config) + US4 (manage-models binary)
- Engineer B: US3 (snap lint, confinement tests) + US2 (presets integration tests)

Both engineers can work after Phase 2 completes. US2 and US3 test writing can begin
concurrently with Phase 2 snap build work since they only need the installed snap.

---

## Notes

- All integration tests require an installed snap on Ubuntu 24.04 with snapd ≥ 2.60
- A small GGUF model (e.g., Phi-3 Mini Q4_K_M, ~2 GB) is needed for US1/US2 tests
- `[P]` tasks = different files, no blocking dependencies
- `[USn]` label maps every task to its user story for traceability
- Commit after each phase checkpoint
- `slot-save-path` MUST NOT appear in the shipped `presets.ini` (see contracts/presets-ini.md)
- Future GPU backends: swap `-DGGML_VULKAN=1` for `-DGGML_HIP=ON` (ROCm) or `-DGGML_CUDA=ON` (CUDA) in `snapcraft.yaml`; CUDA/ROCm require self-hosted build infra
