#!/usr/bin/env python3

import argparse
import configparser
import json
import os
import sys
from pathlib import Path

GLOBAL_SECTION = "*"


def default_presets_path() -> Path | None:
    if snap_user_common := os.environ.get("SNAP_USER_COMMON"):
        return Path(snap_user_common) / "config/presets.ini"
    return None


def default_config_path() -> Path:
    return Path.cwd() / "opencode.jsonc"


def ensure_config_path(config_path: Path) -> Path:
    config_dir = config_path.parent
    config_dir.mkdir(parents=True, exist_ok=True)
    if not config_path.exists():
        config_path.write_text('{"$schema": "https://opencode.ai/config.json"}\n')
    return config_path


def display_name(hf_repo: str) -> str:
    # "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:Q4_K_XL"
    # -> "Qwen3-Coder-30B-A3B-Instruct (Q4_K_XL)"
    repo, _, quant = hf_repo.partition(":")
    model_part = repo.split("/")[-1].removesuffix("-GGUF")
    return f"{model_part} ({quant})" if quant else model_part


def read_presets(presets_path: Path) -> list[dict]:
    parser = configparser.RawConfigParser(default_section=GLOBAL_SECTION)
    with presets_path.open() as presets_file:
        parser.read_file(presets_file)

    entries = []

    for section in parser.sections():
        raw = dict(parser[section])
        try:
            ctx_size = int(raw.get("ctx-size", 0))
        except ValueError:
            print(
                f"Warning: [{section}] ctx-size is not an integer, skipping",
                file=sys.stderr,
            )
            continue
        if not ctx_size:
            print(f"Warning: [{section}] has no ctx-size, skipping", file=sys.stderr)
            continue
        entries.append(
            {
                "slug": section,
                "name": display_name(raw.get("hf-repo", section)),
                "ctx_size": ctx_size,
            }
        )

    return entries


def strip_jsonc_comments(text: str) -> str:
    output = []
    i = 0
    in_string = False
    escape = False

    while i < len(text):
        char = text[i]
        next_char = text[i + 1] if i + 1 < len(text) else ""

        if in_string:
            output.append(char)
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                in_string = False
            i += 1
            continue

        if char == '"':
            in_string = True
            output.append(char)
            i += 1
        elif char == "/" and next_char == "/":
            i += 2
            while i < len(text) and text[i] not in "\r\n":
                i += 1
        elif char == "/" and next_char == "*":
            i += 2
            while i + 1 < len(text) and text[i : i + 2] != "*/":
                i += 1
            i += 2
        else:
            output.append(char)
            i += 1

    return "".join(output)


def remove_trailing_commas(text: str) -> str:
    output = []
    i = 0
    in_string = False
    escape = False

    while i < len(text):
        char = text[i]

        if in_string:
            output.append(char)
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                in_string = False
            i += 1
            continue

        if char == '"':
            in_string = True
            output.append(char)
            i += 1
            continue

        if char == ",":
            lookahead = i + 1
            while lookahead < len(text) and text[lookahead].isspace():
                lookahead += 1
            if lookahead < len(text) and text[lookahead] in "}]":
                i += 1
                continue

        output.append(char)
        i += 1

    return "".join(output)


def load_jsonc(text: str) -> dict:
    return json.loads(remove_trailing_commas(strip_jsonc_comments(text)))


def update_config(entries: list[dict], config_path: Path) -> None:
    config_path = ensure_config_path(config_path)
    text = config_path.read_text()
    config = load_jsonc(text)

    provider = config.setdefault("provider", {})
    llama = provider.get("llama.cpp", {})
    if "llama.cpp" not in provider:
        provider["llama.cpp"] = llama
    llama.setdefault("models", {})
    existing = llama["models"]

    preset_slugs = {e["slug"] for e in entries}
    removed = [slug for slug in existing if slug not in preset_slugs]

    updated: dict = {}
    for e in entries:
        slug = e["slug"]
        n_ctx = e["ctx_size"]
        n_output_default = min(n_ctx // 2, 65536)
        n_output = (
            existing.get(slug, {}).get("limit", {}).get("output", n_output_default)
        )

        if slug in existing:
            entry = {
                **existing[slug],
                "name": e["name"],
                "limit": {"context": n_ctx, "output": n_output},
            }
        else:
            entry = {"name": e["name"], "limit": {"context": n_ctx, "output": n_output}}

        updated[slug] = entry

    llama["models"] = updated

    tmp = config_path.with_suffix(".jsonc.tmp")
    tmp.write_text(json.dumps(config, indent=4) + "\n")
    tmp.rename(config_path)

    print(f"Updated {config_path}")
    for slug, entry in updated.items():
        lim = entry["limit"]
        print(
            f"  [{slug}] {entry.get('name', '')}  ctx={lim['context']}  out={lim['output']}"
        )
    for slug in removed:
        print(f"  removed [{slug}]")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Sync llama.cpp models in opencode config from a presets.ini file"
    )
    parser.add_argument(
        "--presets",
        type=Path,
        default=default_presets_path(),
        help="Path to presets.ini (default: $SNAP_USER_COMMON/config/presets.ini inside the snap)",
    )
    parser.add_argument(
        "--opencode-config",
        type=Path,
        default=default_config_path(),
        help="Path to opencode.jsonc (default: ./opencode.jsonc)",
    )
    args = parser.parse_args()

    presets_path = args.presets
    if not presets_path:
        parser.error("the following argument is required outside the snap: --presets")

    if not presets_path.exists():
        print(f"Presets not found: {presets_path}", file=sys.stderr)
        sys.exit(1)

    entries = read_presets(presets_path)
    if not entries:
        print("No valid model sections in presets.ini", file=sys.stderr)
        sys.exit(1)

    update_config(entries, args.opencode_config)


if __name__ == "__main__":
    main()
