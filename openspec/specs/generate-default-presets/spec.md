# Default Preset Generation Specification

## Purpose

Define the required behavior of `se-llama.generate-presets` for creating and managing the user-owned generated presets file.

## Requirements

### Requirement: Dedicated preset generation command
The system MUST provide a user command to generate `$SNAP_USER_COMMON/config/presets.ini`.

#### Scenario: First-run file creation
- **GIVEN** no existing generated presets file is present
- **WHEN** `se-llama.generate-presets` is run
- **THEN** a new presets file is created in the snap user configuration location

### Requirement: Non-destructive default behavior
The command MUST NOT overwrite an existing generated presets file unless replacement is explicitly requested.

#### Scenario: Existing file preserved by default
- **GIVEN** an existing presets file is present
- **WHEN** the command runs without replacement flags
- **THEN** the file remains unchanged and the user receives a clear status message

### Requirement: Explicit replace semantics
When replacement is requested, the command MUST perform replacement safely and provide clear result reporting.

#### Scenario: Explicit replacement path
- **GIVEN** an existing presets file is present
- **WHEN** the command runs with explicit replacement enabled
- **THEN** replacement is performed with safe handling and reported as a replacement result

### Requirement: Heuristic-based recommended profile selection
The command MUST choose the active recommended model profile from a curated set using simple local system characteristics.

#### Scenario: Conservative fallback on uncertain detection
- **GIVEN** local system characteristics cannot be detected reliably
- **WHEN** presets are generated
- **THEN** the command selects the conservative default profile and reports that choice

### Requirement: Human-editable output with next-step guidance
The generated file and command output MUST clearly identify customizable values and user next steps.

#### Scenario: User can identify what to edit
- **GIVEN** a newly generated presets file
- **WHEN** the user reviews command output and file content
- **THEN** model reference fields and common tuning settings are clearly identifiable
