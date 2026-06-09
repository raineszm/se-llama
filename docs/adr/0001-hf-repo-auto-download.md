# Use hf-repo for model delivery; auto-download on server start

The spec originally required that `se-llama.generate-presets` must not download models. After review, the intended UX is that the Generated Presets File references HuggingFace repositories via the `hf-repo` llama.cpp preset key, and `llama-server` automatically downloads the referenced model on first use (or on startup when `load-on-startup` is set). The Preset Generation Command itself performs no network I/O — the download is delegated entirely to llama-server at runtime.

This was chosen over local file path placeholders (e.g. `model = /path/to/model.gguf`) because it gives users a working server configuration out of the box without manual model management. The trade-off is that first server start triggers a potentially large download; this is surfaced to the user via a warning in `generate-presets` output and in the `run-server` first-run prompt.

The llama.cpp HuggingFace cache is redirected to `$SNAP_USER_COMMON/models/hf` via the `HF_HUB_CACHE` environment variable, keeping all downloaded data within the snap's confined storage area.

## Considered Options

**Local file path placeholder** (`model = $SNAP_USER_COMMON/models/user/my-model.gguf`): Rejected because it requires users to manually download and name model files before the server can start, adding friction for first-time users.

**Bundle model files in the snap**: Rejected because GGUF models are 5–20 GB and change frequently; bundling would make the snap impractically large and stale.
