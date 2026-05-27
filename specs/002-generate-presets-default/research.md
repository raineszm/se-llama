# Research: Generate Default Presets

## Decision: Add a dedicated `se-llama.generate-presets` snap app

**Rationale**: The feature is user-invoked setup behavior, not server startup behavior. Keeping it separate lets users regenerate or inspect defaults without starting llama-server and keeps destructive replacement behind explicit CLI choices.

**Alternatives considered**:
- Seed on every `se-llama.server` start: rejected because it hides setup behavior inside server startup and makes profile selection harder to explain.
- Keep only implicit first-run seeding: rejected because the user asked for a new app and recommended model choices.

## Decision: Implement generation logic in Python with a small shell wrapper

**Rationale**: The project already stages Python for `update-models`, and Python standard library support makes heuristic parsing, atomic file writes, and testable template generation straightforward. A shell wrapper remains useful for matching existing snap app structure.

**Alternatives considered**:
- Pure shell: rejected because parsing memory information, flags, templates, backup naming, and test fixtures would be more brittle.
- Add a third-party templating dependency: rejected because the generated file is simple and extra dependencies add packaging and security cost.

## Decision: Use three recommended model profiles

**Rationale**: Three choices keep the default understandable while covering common local systems: low-resource, balanced, and larger-memory/GPU-capable machines. The generated file should include all recommendations but activate the selected default.

**Recommended profiles**:
- `low`: small instruct model profile, conservative context, CPU-safe defaults.
- `balanced`: mid-size instruct model profile, moderate context, GPU offload when available.
- `large`: larger instruct model profile, larger context, GPU-oriented defaults.

**Alternatives considered**:
- One universal profile: rejected because it does not satisfy the request for several recommended models.
- Many model options: rejected because it creates decision fatigue and increases maintenance burden.

## Decision: Use a simple memory-first heuristic with best-effort GPU detection

**Rationale**: Available memory is the most broadly available signal under strict confinement. GPU detection is useful but must not make generation fail because device visibility depends on confinement and host setup. The heuristic remains deterministic and explainable.

**Rule**:
- If available memory cannot be detected, choose `low` and explain the conservative fallback.
- If available memory is below 12 GiB, choose `low`.
- If available memory is 12-31 GiB, choose `balanced`.
- If available memory is 32 GiB or higher and a render-capable GPU appears available, choose `large`.
- If available memory is 32 GiB or higher but GPU availability is unknown or absent, choose `balanced` unless the user overrides with `--profile large`.

**Alternatives considered**:
- GPU-first selection: rejected because GPU availability is less reliable to detect inside confinement.
- Benchmark-based selection: rejected because generation must be fast and must not load or download models.

## Decision: Do not download or validate model files during generation

**Rationale**: The feature should create configuration, not perform network or model-management actions. This preserves privacy, avoids large downloads, and keeps the command safe in restricted environments.

**Alternatives considered**:
- Download the selected model automatically: rejected because it changes scope, requires network access, and can consume substantial disk space.
- Validate model repositories online: rejected because generation should work offline.

## Decision: Refuse overwrite by default; `--force` creates a backup

**Rationale**: User config is user-owned state. Default no-overwrite behavior satisfies safety requirements. Explicit replacement remains possible for users who want to regenerate from scratch.

**Alternatives considered**:
- Always merge missing recommendations into existing files: rejected because safely editing arbitrary user INI while preserving comments and intent is more complex than this feature needs.
- Always overwrite: rejected because it risks silent data loss.
