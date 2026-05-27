# Data Model: Generate Default Presets

## Preset Generation Command

Represents the user-facing setup action.

**Fields**:
- `profile`: `auto`, `low`, `balanced`, or `large`; default `auto`.
- `force`: boolean; default `false`.
- `dry_run`: boolean; default `false`.
- `target_path`: generated config path, normally `$SNAP_USER_COMMON/config/presets.ini`.

**Validation Rules**:
- `profile` must be one of the supported profile names.
- `force` must be explicit before an existing `presets.ini` is replaced.
- `dry_run` must not write or replace files.

## System Profile

Represents locally observable system characteristics used for recommendation.

**Fields**:
- `memory_gib`: detected available memory, rounded down to GiB, or unknown.
- `gpu_available`: `true`, `false`, or `unknown`.
- `selected_profile`: resulting recommendation.
- `selection_reason`: human-readable explanation shown to the user.

**Validation Rules**:
- Unknown memory must select the conservative `low` profile unless the user explicitly chooses another profile.
- GPU detection failure must not make command execution fail.

## Recommended Model Profile

Represents a curated starter option included in the generated file.

**Fields**:
- `name`: profile key: `low`, `balanced`, or `large`.
- `display_name`: friendly label shown in comments and command output.
- `model_reference`: expected model repository or model file identifier.
- `alias`: API-visible model name for requests.
- `ctx_size`: context window default.
- `n_gpu_layers`: GPU offload recommendation.
- `notes`: short guidance about when to use the profile.

**Validation Rules**:
- Each profile must include a model reference, alias, context size, and GPU layer setting.
- None of the profiles may include `slot-save-path` or any setting that intentionally persists inference data.
- Generated sections must be valid for llama-server native preset parsing when uncommented or selected.

## Generated Presets File

Represents the user-owned `presets.ini` file created by the command.

**Fields**:
- `path`: file destination.
- `global_defaults`: privacy and server defaults applied to presets.
- `active_profile`: selected recommendation.
- `available_profiles`: non-selected recommendations included as discoverable alternatives.
- `comments`: concise user guidance and heuristic explanation.

**Validation Rules**:
- Must be human-readable INI.
- Must include privacy-preserving global defaults.
- Must identify the selected profile and explain how to switch profiles.
- Must not overwrite an existing file unless explicit replacement is requested.

## Write Result

Represents the outcome reported to the user.

**Fields**:
- `status`: `created`, `exists`, `replaced`, `preview`, or `error`.
- `path`: target path.
- `backup_path`: backup path when replacement occurred, otherwise absent.
- `message`: actionable user-facing summary.
- `next_steps`: short guidance for model placement and server startup.

**State Transitions**:
- `absent -> created`: default successful generation.
- `present -> exists`: default no-overwrite behavior.
- `present -> replaced`: explicit replacement with backup.
- `any -> preview`: dry run produces output without mutation.
- `any -> error`: invalid profile, permission failure, or write failure.
