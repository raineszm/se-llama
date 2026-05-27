# Quickstart: Generate Default Presets

## 1. Generate a starter config

```bash
se-llama.generate-presets
```

The command creates the file, prints the selected recommendation, and shows the next step:

```text
~/snap/se-llama/common/config/presets.ini
```

It chooses one recommended profile automatically from simple local system characteristics and prints the reason for the choice.

## 2. Preview without writing

```bash
se-llama.generate-presets --dry-run
```

Use this to inspect the recommended profiles and selected default before creating or replacing the file. Dry run prints generated content only and does not write `presets.ini`.

## 3. Choose a profile manually

```bash
se-llama.generate-presets --profile low
se-llama.generate-presets --profile balanced
se-llama.generate-presets --profile large
```

Profiles are intended as starter points:
- `low`: conservative memory use for smaller systems.
- `balanced`: default workstation profile.
- `large`: larger-memory systems with GPU acceleration available.

The default `--profile auto` uses deterministic thresholds:

```text
unknown memory -> low
below 12 GiB -> low
12-31 GiB -> balanced
32+ GiB with detected GPU -> large
32+ GiB without confirmed GPU -> balanced
```

## 4. Preserve or replace existing config

If `presets.ini` already exists, the command leaves it unchanged.

To regenerate intentionally:

```bash
se-llama.generate-presets --force
```

The command creates a backup beside the original file before replacing it, using the format `presets.ini.backup-YYYYMMDD-HHMMSS`.

## 5. Add model files and start the server

Place model files under:

```text
~/snap/se-llama/common/models/
```

Review `presets.ini` and update the selected profile's model reference if needed, then start:

```bash
se-llama.server
```

Clients select the generated preset by using the preset alias in the OpenAI-compatible `model` field.

## 6. Safety note

The generated file must not include `slot-save-path`. Adding that setting causes llama-server to persist KV cache data on disk, which defeats the default privacy posture.
