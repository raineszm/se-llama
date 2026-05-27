# Feature Specification: Generate Default Presets

**Feature Branch**: `002-generate-presets-default`

**Created**: 2026-05-27

**Status**: Draft

**Input**: User description: "Implement a new app to the snapcraft file that generates a sane default presets.ini for the user. We should have a few recommended models to choose from and pick them based on simple heuristic of the user's system."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create a usable default presets file (Priority: P1)

A user installs the snap and runs a dedicated command to create a default `presets.ini` in the snap's user configuration area. The generated file gives the user a safe starting point for running local models without having to know the full presets format first, and selects a recommended starter model profile from a small curated set based on simple local system characteristics.

**Why this priority**: This is the core value of the feature. Users need a quick, repeatable way to bootstrap the configuration required by the server.

**Independent Test**: Start from a user account with no existing `presets.ini`, run the preset generation command, and confirm a readable `presets.ini` exists with at least one recommended default preset selected from a small curated model set and privacy-preserving defaults.

**Acceptance Scenarios**:

1. **Given** the snap is installed and the user has no existing `presets.ini`, **When** the user runs the preset generation command, **Then** a new `presets.ini` is created in the snap user config location.
2. **Given** the generated `presets.ini` exists, **When** the user opens it, **Then** it contains clear default preset content for a recommended starter model profile that can be edited for the user's model file names and generation preferences.
3. **Given** the generated `presets.ini` exists, **When** the user starts the server using the generated preset after placing a matching model file in the expected models location, **Then** the server can use the preset without requiring additional configuration format changes.

---

### User Story 2 - Preserve user changes (Priority: P2)

A user who already has a `presets.ini` can run the preset generation command without losing manual edits or existing model configurations.

**Why this priority**: Configuration files commonly become user-maintained. The command must not destroy work or silently replace carefully tuned settings.

**Independent Test**: Create a custom `presets.ini`, run the preset generation command, and confirm the command exits safely without overwriting the file unless the user explicitly requests replacement.

**Acceptance Scenarios**:

1. **Given** a user already has a `presets.ini`, **When** the user runs the preset generation command with default options, **Then** the existing file remains unchanged and the user is told where it is.
2. **Given** a user already has a `presets.ini`, **When** the user explicitly requests replacement, **Then** the command creates a new default file only after preserving or warning about the existing file.

---

### User Story 3 - Understand next steps (Priority: P3)

A user who generates the file receives enough guidance to know where models should be placed and which values should be changed before starting the server.

**Why this priority**: A default file is useful only if users can quickly adapt it to their local model names and intended usage.

**Independent Test**: Run the command and inspect both the command output and generated file comments to confirm they identify the file location, expected model location, and the fields most users should edit.

**Acceptance Scenarios**:

1. **Given** the command successfully creates a default `presets.ini`, **When** it completes, **Then** the user sees the path to the generated file and a brief next-step message.
2. **Given** a user opens the generated file, **When** they review the content, **Then** comments or labels identify the model reference and common generation settings users are expected to customize.

---

### User Story 4 - Choose from recommended model profiles (Priority: P3)

A user can see a few recommended model profiles and the command can choose a reasonable default using simple local system heuristics, such as available memory and whether GPU acceleration appears available.

**Why this priority**: A small curated set reduces decision fatigue while still giving users enough flexibility to choose a profile appropriate for their machine.

**Independent Test**: Run the command on representative low-memory, mid-range, and high-memory systems and confirm the selected preset matches the documented recommendation rules.

**Acceptance Scenarios**:

1. **Given** a system with limited memory, **When** the user generates presets, **Then** the generated file selects a smaller recommended model profile by default.
2. **Given** a system with more available memory and GPU acceleration, **When** the user generates presets, **Then** the generated file selects a larger or GPU-oriented recommended model profile by default.
3. **Given** the generated file contains the selected default, **When** the user reviews it, **Then** the other recommended model profiles are discoverable without replacing the generated file.

---

### Edge Cases

- What happens when the user config directory does not exist yet?
- What happens when `presets.ini` already exists and contains custom presets?
- What happens when the config directory cannot be created or written due to permissions or storage errors?
- What happens when the generated preset references a model file the user has not added yet?
- What happens when the command is run repeatedly by the same user?
- What happens when the user's system characteristics cannot be detected reliably?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The installed snap MUST provide a dedicated user-invoked command for generating a default `presets.ini`.
- **FR-002**: The command MUST create the snap user configuration directory if it does not already exist.
- **FR-003**: The command MUST create `presets.ini` in the snap user configuration location when the file is absent.
- **FR-004**: The generated `presets.ini` MUST include at least one default preset selected from a small curated set of recommended model profiles.
- **FR-005**: The generated defaults MUST preserve the project's privacy posture by avoiding settings that intentionally persist prompts, prompt caches, or inference artifacts to disk.
- **FR-006**: The generated file MUST be human-readable and include concise guidance for values users are expected to edit, including model identity or location.
- **FR-007**: The command MUST NOT overwrite an existing `presets.ini` during normal execution.
- **FR-008**: If replacement is supported, the command MUST require an explicit user action and MUST avoid silent data loss.
- **FR-009**: The command MUST report the generated file path after successful creation.
- **FR-010**: The command MUST report a clear, actionable error if it cannot create the directory or file.
- **FR-011**: Running the command repeatedly without replacement MUST be safe and leave the existing file unchanged.
- **FR-012**: The command MUST document the simple heuristic used to choose the default recommended model profile.
- **FR-013**: The generated file MUST make the non-selected recommended model profiles discoverable so users can switch later.
- **FR-014**: If system characteristics cannot be detected reliably, the command MUST choose a conservative default and explain that choice.

### Key Entities

- **Preset Generation Command**: The user-facing command that bootstraps the default configuration file.
- **presets.ini**: The user-owned configuration file containing named model presets and generation defaults.
- **Default Preset**: A starter preset intended to be edited for the user's local model while retaining safe default behavior.
- **Recommended Model Profile**: A curated model option with expected resource needs and preset defaults.
- **System Heuristic**: A simple local rule that chooses the default profile from observable system characteristics.
- **Snap User Configuration Location**: The per-user persistent configuration area where the `presets.ini` file is stored.
- **User Model Reference**: The model name or path value in the preset that the user customizes to match their local model file.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A first-time user can generate a default `presets.ini` in one command in under 10 seconds on a typical Ubuntu workstation.
- **SC-002**: 100% of successful generation runs report the generated file location to the user.
- **SC-003**: Re-running the command 10 consecutive times with an existing `presets.ini` leaves the existing file content unchanged unless replacement is explicitly requested.
- **SC-004**: The generated file contains at least one selected named preset, at least two additional recommended model profiles, and at least three clearly labeled settings that users commonly customize.
- **SC-005**: A user can identify the next required action, such as adding or naming a model file, within 1 minute of reading the command output and generated file comments.
- **SC-006**: Permission or storage failures produce an actionable error message in 100% of tested failure cases.

## Assumptions

- The command is intended for per-user configuration, not system-wide configuration.
- The default file should be safe to regenerate only when the user explicitly asks for replacement.
- The generated preset is a starter template; users are still responsible for adding or selecting their own model files.
- Recommended model profiles are references and defaults only; the feature does not bundle or download the model files.
- The heuristic should use simple, locally observable system characteristics and should prefer a conservative recommendation when unsure.
- Privacy-preserving behavior from the existing snap remains the default expectation for generated presets.
- The feature does not need to download models or validate model availability during preset generation.
