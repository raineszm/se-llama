# se-llama

A strictly confined snap that packages llama.cpp for private, single-user local LLM inference on Ubuntu. The snap exposes CLI apps for server management, model updates, and configuration generation.

## Language

**Preset Generation Command**:
The user-invoked snap app (`se-llama.generate-presets`) that writes a default `presets.ini` to the snap user configuration area.
_Avoid_: config generator, setup command

**Recommended Model Profile**:
One of three curated model configurations (`low`, `balanced`, `large`) that the Preset Generation Command selects from based on detected system characteristics. Each profile references a specific HuggingFace repository and defines inference parameters.
_Avoid_: preset, profile, configuration

**Suggested Model**:
An additional model configuration included in the Generated Presets File for discovery purposes, beyond the three Recommended Model Profiles. Not used for heuristic selection.
_Avoid_: extra preset, bonus model, alternative profile

**System Profile**:
The locally observable hardware characteristics (total RAM, GPU availability) used to choose which Recommended Model Profile to activate. Derived entirely from local reads — no network calls.
_Avoid_: system detection, hardware fingerprint

**Generated Presets File**:
The `presets.ini` file written to `$SNAP_USER_COMMON/config/presets.ini`. Consumed directly by `llama-server` in router mode via `--models-preset`. User-owned: the snap never overwrites it without explicit request.
_Avoid_: config file, ini file, model config

**Write Result**:
The outcome of a Preset Generation Command run: one of `created`, `exists`, `replaced`, `preview`, or `error`. Determines what is printed to the user and what exit code is returned.
_Avoid_: generation result, output status

**Snap User Configuration Location**:
`$SNAP_USER_COMMON/config/` — the per-user persistent directory where the Generated Presets File lives. Accessible under strict snap confinement without additional plugs.
_Avoid_: config dir, user config path

**load-on-startup**:
A llama.cpp preset-only key that causes the router server to load a model immediately on startup rather than on the first request. Set by the Preset Generation Command on the activated Recommended Model Profile.
_Avoid_: autoload, eager load, preload
