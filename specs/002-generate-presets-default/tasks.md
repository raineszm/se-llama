# Tasks: Generate Default Presets

**Input**: Design documents from `specs/002-generate-presets-default/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/generate-presets-cli.md`, `quickstart.md`

**Tests**: Included because the project constitution requires acceptance tests derived from user stories before implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files or has no dependency on incomplete tasks.
- **[Story]**: Maps the task to a user story from `spec.md`.
- Every task includes an exact file path.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add the new snap app entrypoint and test locations without implementing behavior.

- [X] T001 Add `generate-presets` app entry to `snap/snapcraft.yaml` with command path `bin/generate-presets`
- [X] T002 Create executable shell wrapper skeleton in `snap/local/bin/generate-presets`
- [X] T003 [P] Create Python helper skeleton with argument parser entrypoint in `snap/local/libexec/generate_presets.py`
- [X] T004 [P] Create unit test file skeleton in `tests/unit/test_generate_presets.py`
- [X] T005 [P] Create integration test file skeleton in `tests/integration/test_generate_presets.sh`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Implement shared generation primitives that all user stories need.

**Critical**: No user story work can begin until this phase is complete.

- [X] T006 Define recommended profile data for `low`, `balanced`, and `large` in `snap/local/libexec/generate_presets.py`
- [X] T007 Implement `presets.ini` rendering function with privacy-preserving global defaults in `snap/local/libexec/generate_presets.py`
- [X] T008 Implement safe target path resolution using `$SNAP_USER_COMMON/config/presets.ini` in `snap/local/libexec/generate_presets.py`
- [X] T009 Implement reusable atomic write helper for generated files in `snap/local/libexec/generate_presets.py`
- [X] T010 Implement shell wrapper to exec `python3 $SNAP/libexec/generate_presets.py "$@"` in `snap/local/bin/generate-presets`
- [X] T011 [P] Add lint test for snapcraft app and staged files in `tests/lint/test_generate_presets_app.sh`

**Checkpoint**: Shared generation and packaging scaffolding are ready for story implementation.

---

## Phase 3: User Story 1 - Create a usable default presets file (Priority: P1) MVP

**Goal**: A first-time user can run one command and get a valid, privacy-preserving `presets.ini`.

**Independent Test**: From an empty snap user common directory, run the command and verify `config/presets.ini` exists, contains an active selected preset, and omits `slot-save-path`.

### Tests for User Story 1

- [X] T012 [P] [US1] Add unit test for rendering active selected preset without `slot-save-path` in `tests/unit/test_generate_presets.py`
- [X] T013 [P] [US1] Add unit test for creating missing config directory and file in `tests/unit/test_generate_presets.py`
- [X] T014 [P] [US1] Add integration test for first-run `se-llama.generate-presets` file creation in `tests/integration/test_generate_presets.sh`

### Implementation for User Story 1

- [X] T015 [US1] Implement default `--profile auto` command flow for absent `presets.ini` in `snap/local/libexec/generate_presets.py`
- [X] T016 [US1] Implement successful creation output with generated path, selected profile, and next step in `snap/local/libexec/generate_presets.py`
- [X] T017 [US1] Wire helper invocation and environment validation in `snap/local/bin/generate-presets`
- [X] T018 [US1] Ensure `snap/local/etc/se-llama/presets.ini` remains compatible with generated content expectations

**Checkpoint**: User Story 1 is independently functional and testable as the MVP.

---

## Phase 4: User Story 2 - Preserve user changes (Priority: P2)

**Goal**: Existing user config is not overwritten unless the user explicitly requests replacement.

**Independent Test**: Create a custom `presets.ini`, run generation normally, and verify the file is unchanged; run with `--force` and verify a backup exists before replacement.

### Tests for User Story 2

- [X] T019 [P] [US2] Add unit test for no-overwrite behavior when target file exists in `tests/unit/test_generate_presets.py`
- [X] T020 [P] [US2] Add unit test for `--force` backup path and replacement behavior in `tests/unit/test_generate_presets.py`
- [X] T021 [P] [US2] Add integration test for preserving existing `presets.ini` without `--force` in `tests/integration/test_generate_presets.sh`

### Implementation for User Story 2

- [X] T022 [US2] Implement existing-file detection and unchanged exit path in `snap/local/libexec/generate_presets.py`
- [X] T023 [US2] Implement `--force` backup creation and replacement flow in `snap/local/libexec/generate_presets.py`
- [X] T024 [US2] Implement no-change and replacement messages in `snap/local/libexec/generate_presets.py`

**Checkpoint**: User Story 2 is independently functional and preserves user-owned config.

---

## Phase 5: User Story 3 - Understand next steps (Priority: P3)

**Goal**: Command output and generated file comments tell users where the file is, where models go, and which fields to edit.

**Independent Test**: Run the command, inspect stdout and `presets.ini`, and verify both contain concise guidance for file location, model placement, profile switching, and safe settings.

### Tests for User Story 3

- [X] T025 [P] [US3] Add unit test for generated comments containing model path and editable fields in `tests/unit/test_generate_presets.py`
- [X] T026 [P] [US3] Add integration test for stdout next-step guidance in `tests/integration/test_generate_presets.sh`

### Implementation for User Story 3

- [X] T027 [US3] Add generated-file comments for model placement, profile switching, and editable settings in `snap/local/libexec/generate_presets.py`
- [X] T028 [US3] Add stdout next-step guidance for model placement and `se-llama.server` startup in `snap/local/libexec/generate_presets.py`
- [X] T029 [US3] Document generated preset workflow in `specs/002-generate-presets-default/quickstart.md`

**Checkpoint**: User Story 3 is independently functional and improves user comprehension.

---

## Phase 6: User Story 4 - Choose from recommended model profiles (Priority: P3)

**Goal**: The command selects a recommended profile using simple local heuristics and includes alternative profiles for later switching.

**Independent Test**: Simulate low-memory, balanced, large-memory-with-GPU, and unknown-detection systems and verify selected profiles match the contract.

### Tests for User Story 4

- [X] T030 [P] [US4] Add unit tests for memory-first auto-selection thresholds in `tests/unit/test_generate_presets.py`
- [X] T031 [P] [US4] Add unit tests for unknown memory fallback and GPU detection fallback in `tests/unit/test_generate_presets.py`
- [X] T032 [P] [US4] Add unit test for `--profile low|balanced|large` override behavior in `tests/unit/test_generate_presets.py`
- [X] T033 [P] [US4] Add integration test for generated file containing all three recommended profiles in `tests/integration/test_generate_presets.sh`

### Implementation for User Story 4

- [X] T034 [US4] Implement local memory detection from `/proc/meminfo` in `snap/local/libexec/generate_presets.py`
- [X] T035 [US4] Implement best-effort GPU availability detection without failing generation in `snap/local/libexec/generate_presets.py`
- [X] T036 [US4] Implement `auto`, `low`, `balanced`, and `large` profile selection logic in `snap/local/libexec/generate_presets.py`
- [X] T037 [US4] Render selected profile active and non-selected profiles discoverable in `snap/local/libexec/generate_presets.py`
- [X] T038 [US4] Update CLI contract examples for heuristic and profile override behavior in `specs/002-generate-presets-default/contracts/generate-presets-cli.md`

**Checkpoint**: User Story 4 is independently functional and recommendation behavior is deterministic.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Validate full feature behavior, packaging, and documentation.

- [X] T039 [P] Run and fix Python unit tests for `tests/unit/test_generate_presets.py`
- [X] T040 [P] Run and fix integration tests for `tests/integration/test_generate_presets.sh`
- [X] T041 Run and fix snap app lint coverage in `tests/lint/test_generate_presets_app.sh`
- [X] T042 Run and fix full snap lint validation in `tests/lint/test_snap_lint.sh`
- [X] T043 Validate quickstart commands and expected output in `specs/002-generate-presets-default/quickstart.md`
- [X] T044 Review generated config for privacy regressions against `specs/001-llama-cpp-snap/contracts/presets-ini.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion; blocks all user stories.
- **User Stories (Phase 3+)**: Depend on Foundational completion.
- **Polish (Phase 7)**: Depends on completed desired user stories.

### User Story Dependencies

- **User Story 1 (P1)**: Starts after Foundational; no dependency on other stories; suggested MVP.
- **User Story 2 (P2)**: Starts after Foundational; can be implemented after or alongside US1 because it extends write behavior.
- **User Story 3 (P3)**: Starts after Foundational; can be implemented after US1 or alongside US2.
- **User Story 4 (P3)**: Starts after Foundational; can be implemented after profile data exists from T006.

### Within Each User Story

- Tests must be written and observed failing before implementation tasks.
- Shared helper primitives before story command flows.
- Command behavior before final packaging validation.
- Story checkpoint must pass before treating the story as complete.

---

## Parallel Opportunities

- T003, T004, and T005 can run in parallel after T001 and T002 are assigned.
- T011 can run in parallel with T006-T010 because it targets a separate lint test file.
- US1 test tasks T012-T014 can run in parallel.
- US2 test tasks T019-T021 can run in parallel.
- US3 test tasks T025-T026 can run in parallel.
- US4 test tasks T030-T033 can run in parallel.
- After Foundational completion, US2, US3, and US4 can proceed in parallel if US1's core generation flow is not being changed in the same file at the same time.

---

## Parallel Example: User Story 1

```bash
Task: "Add unit test for rendering active selected preset without slot-save-path in tests/unit/test_generate_presets.py"
Task: "Add unit test for creating missing config directory and file in tests/unit/test_generate_presets.py"
Task: "Add integration test for first-run se-llama.generate-presets file creation in tests/integration/test_generate_presets.sh"
```

## Parallel Example: User Story 2

```bash
Task: "Add unit test for no-overwrite behavior when target file exists in tests/unit/test_generate_presets.py"
Task: "Add unit test for --force backup path and replacement behavior in tests/unit/test_generate_presets.py"
Task: "Add integration test for preserving existing presets.ini without --force in tests/integration/test_generate_presets.sh"
```

## Parallel Example: User Story 4

```bash
Task: "Add unit tests for memory-first auto-selection thresholds in tests/unit/test_generate_presets.py"
Task: "Add unit tests for unknown memory fallback and GPU detection fallback in tests/unit/test_generate_presets.py"
Task: "Add unit test for --profile low|balanced|large override behavior in tests/unit/test_generate_presets.py"
Task: "Add integration test for generated file containing all three recommended profiles in tests/integration/test_generate_presets.sh"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational.
3. Complete Phase 3: User Story 1.
4. Stop and validate first-run generation independently.
5. Demo `se-llama.generate-presets` creating a safe `presets.ini`.

### Incremental Delivery

1. Add User Story 1 for first-run generation.
2. Add User Story 2 for non-destructive replacement behavior.
3. Add User Story 3 for user guidance.
4. Add User Story 4 for model recommendations and heuristic selection.
5. Run Phase 7 validation after the selected story set is complete.

### Parallel Team Strategy

1. One developer handles snap metadata and wrapper setup in `snap/snapcraft.yaml` and `snap/local/bin/generate-presets`.
2. One developer handles helper behavior in `snap/local/libexec/generate_presets.py`.
3. One developer handles tests in `tests/unit/test_generate_presets.py`, `tests/integration/test_generate_presets.sh`, and `tests/lint/test_generate_presets_app.sh`.

---

## Notes

- Keep generated config compatible with llama-server native preset parsing.
- Do not add `slot-save-path` to generated presets.
- Do not add network access or model downloads to this feature.
- Commit after each completed story or coherent task group.
