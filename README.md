# se-llama

Strictly confined snap packaging for `llama.cpp` with Vulkan GPU acceleration.

## Build Requirements

- Snapcraft 9 or newer is required. The snap uses the `gpu` extension for core24 GPU runtime setup.

## Build

```bash
snapcraft pack
```

## Install

Install the locally built snap:

```bash
sudo snap install ./se-llama_*.snap --dangerous
```

Connect the interfaces needed for GPU access and local server binding:

```bash
sudo snap connect se-llama:opengl
sudo snap connect se-llama:network-bind
```

## Basic Usage

Edit the generated preset configuration and add a model section that uses a
Hugging Face GGUF repository:

```bash
nano ~/snap/se-llama/common/config/presets.ini
```

Example preset:

```ini
[example-model]
hf-repo = owner/model-GGUF:Q4_K_M
alias = example-model
n-gpu-layers = 99
ctx-size = 4096
```

Replace `owner/model-GGUF:Q4_K_M` with the Hugging Face GGUF repo and
quantization you want to run. If the repo has multiple GGUF files and the
quantization suffix is not enough to select the right one, add `hf-file`:

```ini
[example-model]
hf-repo = owner/model-GGUF
hf-file = example-model-q4_k_m.gguf
alias = example-model
n-gpu-layers = 99
ctx-size = 4096
```

Start the llama.cpp server:

```bash
se-llama.server
```

Check that the server is ready:

```bash
curl http://127.0.0.1:8080/health
```

Send an OpenAI-compatible completion request. The `model` value must match a
section name or alias in `presets.ini`:

```bash
curl http://127.0.0.1:8080/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{"model": "example-model", "prompt": "The capital of France is", "max_tokens": 16}'
```

To run a single model directly without adding a preset:

```bash
se-llama.server --hf-repo owner/model-GGUF:Q4_K_M
```

To sync model presets into an OpenCode config:

```bash
se-llama.update-models --opencode-config ~/.config/opencode/opencode.jsonc
```
