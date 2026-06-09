# llama.cpp Snap Runtime Specification

## Purpose

Define the required runtime behavior of the strictly confined `se-llama` snap for local llama.cpp inference.

## Requirements

### Requirement: Strictly confined server runtime
The system MUST run `llama-server` as a strict-confinement snap app and deny out-of-bounds filesystem access.

#### Scenario: Out-of-bounds model path denied
- **GIVEN** the snap is installed with strict confinement
- **WHEN** a model path outside snap-managed storage is used
- **THEN** AppArmor denies access and the command exits with a clear error

### Requirement: Privacy-preserving default runtime
The system MUST default to non-persistent inference behavior and avoid writing prompt or KV cache artifacts to disk.

#### Scenario: No cache artifacts after server stop
- **GIVEN** the server handled inference requests
- **WHEN** the server stops and snap data directories are inspected
- **THEN** no prompt/KV cache artifacts are present

### Requirement: Preset-driven model routing
The system MUST support router-mode model selection via `presets.ini` and apply named preset parameters to requests.

#### Scenario: Named preset selected by request model
- **GIVEN** `$SNAP_USER_COMMON/config/presets.ini` contains a preset section
- **WHEN** a request uses that preset name in the `model` field
- **THEN** the server uses the corresponding parameters

### Requirement: Native llama.cpp build with Vulkan
The snap build MUST compile upstream llama.cpp with Vulkan backend enabled.

#### Scenario: Build artifact supports Vulkan backend
- **GIVEN** a clean snap build
- **WHEN** the packaged binaries are produced
- **THEN** llama.cpp was built from upstream source with Vulkan support enabled

### Requirement: Operational snap quality gates
The package MUST pass `snap lint` in strict confinement mode.

#### Scenario: Lint passes without errors
- **GIVEN** the produced snap artifact
- **WHEN** `snap lint` is run
- **THEN** lint reports zero errors
