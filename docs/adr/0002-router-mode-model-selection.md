# Use llama-server router mode with user-owned presets as model contract

The server is operated in router mode with a user-owned presets file as the model-selection contract. Multiple model configurations are defined once, and API clients choose a model per request using the model identifier from the request payload.

This was chosen over single-model startup wiring because support workflows need one long-running server process that can expose multiple tuned configurations without restarting the service for each model choice. It also keeps configuration ownership with the user rather than in wrapper-only flags.

Trade-off: startup validation becomes stricter because malformed or unknown preset keys fail server start. This is acceptable because explicit startup failure is safer than silently running with partial or divergent configuration.

## Considered Options

**Single-model startup (`--model` only):** Rejected because each model switch requires a restart and does not scale to curated multi-profile workflows.

**Wrapper-level custom preset parsing and flag translation:** Rejected because it duplicates parser behavior already owned by llama-server and risks semantic drift from upstream.