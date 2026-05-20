# Contract: se-llama.models CLI Interface

**Type**: CLI command contract
**App**: `se-llama.models`
**Binary**: `$SNAP/bin/manage-models`

---

## Invocation

```
se-llama.models <subcommand> [options]
```

---

## Subcommands

### `list`

```
se-llama.models list [--format json|table]
```

List all GGUF model files found in `$SNAP_USER_COMMON/models/`.

**Output (table, default)**:
```
NAME                         SIZE      ARCH    QUANT
phi-3-mini-q4.gguf           2.3 GB    phi3    Q4_K_M
llama-3.1-8b-q5.gguf         5.8 GB    llama   Q5_K_M
```

**Output (json)**:
```json
[
  {
    "name": "phi-3-mini-q4.gguf",
    "path": "/home/user/snap/se-llama/common/models/phi-3-mini-q4.gguf",
    "size_bytes": 2468112384,
    "architecture": "phi3",
    "quantization": "Q4_K_M",
    "context_length": 4096,
    "gguf_version": 3
  }
]
```

**Exit codes**: `0` success, `1` models directory unreadable.

---

### `validate`

```
se-llama.models validate <filename-or-path>
```

Validate a GGUF model file: check magic bytes, version, and metadata readability.

**Output (success)**:
```
✓ phi-3-mini-q4.gguf: valid GGUF v3 (phi3, Q4_K_M, ctx=4096)
```

**Output (failure)**:
```
✗ notamodel.bin: invalid magic bytes (expected GGUF, got ???)
```

**Exit codes**: `0` valid, `1` invalid or unreadable.

---

### `info`

```
se-llama.models info <filename-or-path>
```

Print detailed metadata for a GGUF model file.

**Output**:
```
File:           phi-3-mini-q4.gguf
Path:           /home/user/snap/se-llama/common/models/phi-3-mini-q4.gguf
Size:           2.3 GB (2,468,112,384 bytes)
GGUF version:   3
Architecture:   phi3
Quantization:   Q4_K_M
Context length: 4096
Parameters:     ~3.8B
```

**Exit codes**: `0` success, `1` file not found or unreadable, `2` invalid GGUF.

---

## Models directory

Default: `$SNAP_USER_COMMON/models/`

If the directory does not exist, `se-llama.models list` MUST print:
```
Models directory not found: ~/snap/se-llama/common/models/
Create it with: mkdir -p ~/snap/se-llama/common/models/
```
and exit 0 (not an error — the snap is simply unconfigured).

---

## Exit codes (all subcommands)

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Filesystem error (unreadable file/directory) |
| `2` | Invalid GGUF format |
| `3` | Unknown subcommand |
