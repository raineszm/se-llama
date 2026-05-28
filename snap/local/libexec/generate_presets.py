#!/usr/bin/env python3
"""Generate a privacy-preserving se-llama presets.ini."""

from __future__ import annotations

import argparse
import os
import shutil

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


PROFILE_CHOICES = ("auto", "low", "balanced", "large")


@dataclass(frozen=True)
class ModelProfile:
    """A model preset entry for presets.ini."""

    name: str
    display_name: str
    model_reference: str
    notes: str
    params: dict[str, str]

    def render(
        self, annotation: str | None = None, default: bool = False
    ) -> list[str]:
        """Render this model as INI lines for presets.ini.

        If annotation is provided, it is appended to the display name comment.
        If default is True, a default-model marker is included.
        """
        header = f"; {self.display_name}"
        if annotation:
            header += f": {annotation}"
        lines = [
            header,
            f"; {self.notes}",
            f"[{self.name}]",
            f"hf-repo = {self.model_reference}",
        ]
        if default:
            lines.append("default-model = true")
        for key, value in self.params.items():
            lines.append(f"{key} = {value}")
        lines.append("")
        return lines


@dataclass(frozen=True)
class SelectedProfile:
    """Profile selected for the generated recommendation."""

    name: str
    reason: str


PROFILES: dict[str, ModelProfile] = {
    "low": ModelProfile(
        name="low",
        display_name="Low resource",
        model_reference="unsloth/gemma-4-E4B-it-GGUF:Q4_K_M",
        notes="Gemma 4 E4B 4-bit (~5.5 GB); dense model, CPU-friendly for systems under 12 GiB.",
        params={
            "alias": "se-llama-low",
            "ctx-size": "8192",
            "n-gpu-layers": "0",
        },
    ),
    "balanced": ModelProfile(
        name="balanced",
        display_name="Balanced workstation",
        model_reference="unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL",
        notes="Gemma 4 26B-A4B dynamic 4-bit (~18 GB); MoE with 4B active params, best speed/quality tradeoff.",
        params={
            "alias": "se-llama-balanced",
            "ctx-size": "32768",
            "n-gpu-layers": "99",
        },
    ),
    "large": ModelProfile(
        name="large",
        display_name="Large GPU system",
        model_reference="unsloth/gemma-4-31B-it-GGUF:UD-Q4_K_XL",
        notes="Gemma 4 31B dynamic 4-bit (~20 GB); strongest Gemma 4 model for 32+ GiB with GPU.",
        params={
            "alias": "se-llama-large",
            "ctx-size": "32768",
            "n-gpu-layers": "99",
        },
    ),
}


SUGGESTED_MODELS: list[ModelProfile] = [
    ModelProfile(
        name="qwen-coder",
        display_name="Qwen3 Coder 30B-A3B",
        model_reference="unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:Q4_K_XL",
        notes="MoE coding specialist (3B active); strong for code generation and tool use.",
        params={
            "jinja": "true",
            "ctx-size": "65536",
            "top-k": "20",
            "temp": "0.7",
            "min-p": "0.0",
            "top-p": "0.80",
            "repeat-penalty": "1.05",
        },
    ),
    ModelProfile(
        name="gemma4",
        display_name="Gemma 4 26B-A4B",
        model_reference="unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q4_K_XL",
        notes="Gemma 4 26B MoE with full recommended settings and thinking enabled.",
        params={
            "ctx-size": "131072",
            "temp": "1.0",
            "top-p": "0.95",
            "top-k": "64",
            # Inner quotes are intentional: llama-server parses this as a JSON string value.
            "chat-template-kwargs": '{"enable_thinking":true}',
        },
    ),
    ModelProfile(
        name="gpt-oss",
        display_name="GPT-OSS 20B",
        model_reference="unsloth/gpt-oss-20b-GGUF:F16",
        notes="Full-precision 20B dense model; requires ~40 GB RAM.",
        params={
            "ctx-size": "131072",
            "temp": "1.0",
            "top-p": "1.0",
            "top-k": "0",
        },
    ),
    ModelProfile(
        name="qwen3.6",
        display_name="Qwen 3.6 35B-A3B",
        model_reference="unsloth/Qwen3.6-35B-A3B-GGUF:UD-Q4_K_XL",
        notes="MoE general-purpose (3B active); strong reasoning with long context.",
        params={
            "ctx-size": "131072",
            "temp": "1.0",
            "top-p": "0.95",
            "top-k": "20",
            "presence-penalty": "1.5",
        },
    ),
    ModelProfile(
        name="gemma4-e4b",
        display_name="Gemma 4 E4B (Q8)",
        model_reference="unsloth/gemma-4-E4B-it-GGUF:Q8_0",
        notes="Gemma 4 E4B at 8-bit (~9-12 GB); higher quality than Q4 for capable systems.",
        params={
            "ctx-size": "32768",
            "temp": "1.0",
            "top-p": "0.95",
            "top-k": "64",
        },
    ),
]


def build_parser() -> argparse.ArgumentParser:
    """Create the generate-presets command-line parser."""
    parser = argparse.ArgumentParser(
        description="Generate a safe starter presets.ini for se-llama."
    )
    parser.add_argument("--profile", choices=PROFILE_CHOICES, default="auto")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser


def target_path() -> Path:
    """Return the presets.ini path inside SNAP_USER_COMMON."""
    return Path(os.environ["SNAP_USER_COMMON"]) / "config" / "presets.ini"


def detect_memory_gib() -> int:
    """Detect total physical memory in GiB from procfs.

    Uses MemTotal (not MemAvailable) for stable hardware classification
    independent of current system load.  /proc/meminfo reports in KiB
    (binary kilobytes, despite the kernel printing "kB").
    """
    for line in Path("/proc/meminfo").read_text(encoding="utf-8").splitlines():
        if line.startswith("MemTotal:"):
            kib = int(line.split()[1])
            return kib // 1024 // 1024
    raise RuntimeError("MemTotal not found in /proc/meminfo")


def detect_gpu_available() -> bool:
    """Detect GPU availability via /dev/dri or /dev/nvidia0.

    Note: under strict snap confinement these device paths may not be
    visible unless the appropriate plug (e.g. opengl, gpu-2404) is
    connected.  A False result does not guarantee the absence of a GPU.
    """
    dri_path = Path("/dev/dri")
    if dri_path.exists() and any(dri_path.iterdir()):
        return True
    if Path("/dev/nvidia0").exists():
        return True
    return False


def select_profile(
    requested: str, memory_gib: int, gpu_available: bool
) -> SelectedProfile:
    """Select the requested or heuristic profile."""
    if requested != "auto":
        return SelectedProfile(requested, f"profile override requested: {requested}")

    if memory_gib < 12:
        return SelectedProfile(
            "low", f"detected {memory_gib} GiB total RAM; avoiding overcommit"
        )
    if memory_gib < 30:
        return SelectedProfile(
            "balanced",
            f"detected {memory_gib} GiB total RAM; typical workstation default",
        )
    if gpu_available:
        return SelectedProfile(
            "large", f"detected {memory_gib} GiB total RAM and GPU availability"
        )
    return SelectedProfile(
        "balanced", f"detected {memory_gib} GiB total RAM but no confirmed GPU"
    )


def render_presets(selected_profile: str, reason: str) -> str:
    """Render a human-readable presets.ini with safe defaults."""
    lines = [
        "; Generated by se-llama.generate-presets",
        f"; Selected profile: {selected_profile} ({reason})",
        "; To switch profiles, send the desired alias as the OpenAI API model value.",
        "; Edit hf-repo, alias, ctx-size, or n-gpu-layers to match your model and hardware.",
        "; Privacy: this file disables prompt caching and omits persistent inference storage.",
        "",
        "[*]",
        "no-cache-prompt = true",
        "host = 127.0.0.1",
        "port = 8080",
        "jinja = true",
        "",
    ]

    for name in ("low", "balanced", "large"):
        profile = PROFILES[name]
        lines.extend(profile.render(default=name == selected_profile))

    # Suggested models (skip any whose model_reference matches a recommended profile)
    recommended_refs = {p.model_reference for p in PROFILES.values()}
    suggestions = [
        s for s in SUGGESTED_MODELS if s.model_reference not in recommended_refs
    ]
    if suggestions:
        lines.append("; --- Additional suggested models ---")
        lines.append("")
        for suggestion in suggestions:
            lines.extend(suggestion.render())

    return "\n".join(lines)


def backup_path(path: Path) -> Path:
    """Return a timestamped backup path for presets.ini replacement."""
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    candidate = path.with_name(f"{path.name}.backup-{timestamp}")
    counter = 1
    while candidate.exists():
        candidate = path.with_name(f"{path.name}.backup-{timestamp}-{counter}")
        counter += 1
        if counter > 1000:
            raise RuntimeError(f"Too many backup files for {path.name}")
    return candidate


def main(argv: list[str] | None = None) -> int:
    """Run the generate-presets CLI."""
    args = build_parser().parse_args(argv)

    path = target_path()
    selected = select_profile(args.profile, detect_memory_gib(), detect_gpu_available())
    content = render_presets(selected.name, selected.reason)

    if args.dry_run:
        print(f"Preview presets.ini: {path}")
        print(f"Selected profile: {selected.name} ({selected.reason})")
        print(content)
        return 0

    if path.exists() and not args.force:
        print(f"presets.ini already exists: {path}")
        print(
            "No changes made. Use --force to replace after backup or --dry-run to preview defaults.",
        )
        return 0

    replaced = path.exists()
    backup = None
    if replaced:
        backup = backup_path(path)
        shutil.copy2(path, backup)

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")

    if replaced:
        print(f"Replaced presets.ini: {path}")
        print(f"Backup: {backup}")
    else:
        print(f"Created presets.ini: {path}")
    print(f"Selected profile: {selected.name} ({selected.reason})")
    print("Next: run se-llama.server")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
