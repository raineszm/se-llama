# Quickstart: se-llama Snap

**Branch**: `001-llama-cpp-snap`
**Updated**: 2026-05-20

---

## Prerequisites

- Ubuntu 24.04 LTS (or later) — or any system with snapd ≥ 2.60
- For GPU acceleration: a Vulkan-capable GPU with drivers installed
  (AMD Mesa ≥ 23.x, Intel ANV ≥ Mesa 23.x, or NVIDIA with Vulkan support)
- At least one GGUF model file downloaded separately

---

## Install

```bash
# From the snap store (once published):
sudo snap install se-llama

# During development (local build):
snapcraft
sudo snap install se-llama_*.snap --dangerous
```

Connect the required interfaces (not auto-connected):

```bash
sudo snap connect se-llama:opengl        # GPU access
sudo snap connect se-llama:network-bind  # localhost server binding
```

---

## Place a model

The snap's model directory is `~/snap/se-llama/common/models/`. Create it and copy or
symlink your GGUF model there:

```bash
mkdir -p ~/snap/se-llama/common/models/
cp ~/Downloads/phi-3-mini-q4_k_m.gguf ~/snap/se-llama/common/models/
```

## Start the server (router mode)

The snap runs llama-server in **router mode** — no `--model` flag at startup. Models
are defined in `presets.ini` and selected per-request by the client.

```bash
# Start with default presets.ini (seeded automatically on first run):
se-llama.server

# Override the port or any other llama-server flag:
se-llama.server --port 9090
```

Check server health:

```bash
curl http://127.0.0.1:8080/health
# {"status":"ok"}
```

---

## Run an inference

Specify the model by preset name (matches the `[section]` or `alias` in `presets.ini`):

```bash
curl http://127.0.0.1:8080/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{"model": "phi3-mini", "prompt": "The capital of France is", "max_tokens": 10}'
```

---

## Run a single model without presets

To bypass `presets.ini` and load one model directly:

```bash
se-llama.server --model ~/snap/se-llama/common/models/phi-3-mini-q4_k_m.gguf
```

---

## Configure presets

Edit `~/snap/se-llama/common/config/presets.ini` to define named model configurations:

```bash
nano ~/snap/se-llama/common/config/presets.ini
```

Example `presets.ini`:

```ini
; Global defaults (applied to all presets)
[*]
no-cache-prompt = true
cache-ram = 0
host = 127.0.0.1
port = 8080

; GPU-accelerated
[phi3-mini]
model = /home/myuser/snap/se-llama/common/models/phi-3-mini-q4_k_m.gguf
alias = phi3-mini
n-gpu-layers = 99
ctx-size = 4096

; CPU-only fallback
[phi3-mini-cpu]
model = /home/myuser/snap/se-llama/common/models/phi-3-mini-q4_k_m.gguf
alias = phi3-mini-cpu
n-gpu-layers = 0
```

> **Note**: Unknown keys are a fatal error at startup (llama-server validates all keys).
> Do not add `slot-save-path` unless you intend to write KV cache data to disk.

---

## Data audit (support engineering)

After stopping the server, verify no inference artifacts remain:

```bash
# Check snap data directories for cache files:
find ~/snap/se-llama/ -name "*.cache" -o -name "*.kv" -o -name "*.tmp" 2>/dev/null
# Expected output: (empty)

# The only files present should be:
# ~/snap/se-llama/common/models/      — your model files
# ~/snap/se-llama/common/config/      — presets.ini
# ~/snap/se-llama/<rev>/logs/         — log files
```

---

## Full data removal

```bash
# Remove snap and ALL data for the current user:
sudo snap remove --purge se-llama

# Multi-user systems: also remove data for other users who ran the snap:
# (run as root or with sudo)
sudo rm -rf /home/<other-user>/snap/se-llama/
```

> **Note**: `snap remove --purge` only cleans up the invoking user's data. On
> multi-user systems, administrators must manually remove `~/snap/se-llama/` for
> each affected user to achieve complete data purge.

---

## Build from source

```bash
# Clone this repository:
git clone <repo-url> se-llama
cd se-llama

# Install snapcraft:
sudo snap install snapcraft --classic

# Build (requires LXD or Multipass for the build environment):
snapcraft

# The resulting snap: se-llama_<version>_amd64.snap
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Permission denied` on GPU | `opengl` interface not connected | `sudo snap connect se-llama:opengl` |
| Server binds to wrong address | `host` in preset overridden | Check `presets.ini` `[default]` section |
| `"model not found"` API error | Preset name in request doesn't match any section/alias | Check section names in `presets.ini` |
| Unknown key error at startup | Key in `presets.ini` not recognized by llama-server | Remove or correct the key; all keys must be valid llama-server flags |
| GPU not detected, falls back to CPU | No Vulkan ICD found | Verify GPU drivers: `vulkaninfo --summary` |
| Server already running | Stale pidfile | `rm ~/snap/se-llama/common/run/llama-server.pid` |
