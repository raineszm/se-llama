# Contract: se-llama.generate-presets CLI Interface

**Type**: CLI command contract
**App**: `se-llama.generate-presets`
**Purpose**: Generate a safe starter `presets.ini` for llama-server router mode.

---

## Invocation

```bash
se-llama.generate-presets [--profile auto|low|balanced|large] [--force] [--dry-run]
```

Default invocation:

```bash
se-llama.generate-presets
```

Explicit heuristic invocation:

```bash
se-llama.generate-presets --profile auto
```

Manual override examples:

```bash
se-llama.generate-presets --profile low
se-llama.generate-presets --profile balanced
se-llama.generate-presets --profile large
```

Creates:

```text
$SNAP_USER_COMMON/config/presets.ini
```

---

## Options

| Option | Default | Behavior |
|---|---:|---|
| `--profile auto` | yes | Select a recommended profile using local system heuristics |
| `--profile low` | no | Force the low-resource recommendation |
| `--profile balanced` | no | Force the balanced recommendation |
| `--profile large` | no | Force the large-system recommendation |
| `--force` | no | Replace an existing `presets.ini` after creating a backup |
| `--dry-run` | no | Print the generated file and selected recommendation without writing files |

Invalid profile values are errors.

---

## Heuristic Contract

When `--profile auto` is used, selection is deterministic:

| Detected System | Selected Profile | Reason |
|---|---|---|
| Memory unknown | `low` | Conservative fallback |
| Memory below 12 GiB | `low` | Avoid overcommitting smaller systems |
| Memory 12-31 GiB | `balanced` | Suitable default for typical workstations |
| Memory 32 GiB or higher with GPU available | `large` | Larger profile likely viable |
| Memory 32 GiB or higher without GPU or unknown GPU | `balanced` | Avoid assuming GPU acceleration |

GPU detection is best effort. Failure to detect a GPU must not fail the command.

---

## File Behavior

| Condition | Result | Exit Code |
|---|---|---:|
| Target file absent | Create file | `0` |
| Target file exists, no `--force` | Leave unchanged and report path | `0` |
| Target file exists with `--force` | Create backup, write replacement | `0` |
| `--dry-run` | Print generated content only | `0` |
| Config directory cannot be created | Print actionable error | `1` |
| File cannot be written | Print actionable error | `1` |
| Invalid option | Print usage error | `2` |

Replacement backup path format:

```text
$SNAP_USER_COMMON/config/presets.ini.backup-YYYYMMDD-HHMMSS
```

---

## Generated Content Requirements

The generated `presets.ini` must include:

- A global defaults section with privacy-preserving behavior.
- One active selected profile.
- Two additional recommended profiles as discoverable alternatives.
- Comments explaining the selection heuristic and how to switch profiles.
- Model references that users can match by placing files in `$SNAP_USER_COMMON/models/` or by using llama-server supported repository references.

The generated `presets.ini` must not include `slot-save-path`.

---

## Output

Successful creation prints:

```text
Created presets.ini: <path>
Selected profile: <profile> (<reason>)
Next: add the referenced model to <models-path>, then run se-llama.server
```

Existing file without replacement prints:

```text
presets.ini already exists: <path>
No changes made. Use --force to replace after backup or --dry-run to preview defaults.
```

Errors must state what failed and how the user can address it.
