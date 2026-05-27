#!/bin/bash
# Validate se-llama.generate-presets snap metadata and staged files.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SNAPCRAFT="$REPO_ROOT/snap/snapcraft.yaml"

grep -q "  generate-presets:" "$SNAPCRAFT"
grep -q "command: bin/generate-presets" "$SNAPCRAFT"
grep -q "bin/generate-presets: bin/generate-presets" "$SNAPCRAFT"
grep -q "libexec/generate_presets.py: libexec/generate_presets.py" "$SNAPCRAFT"
test -x "$REPO_ROOT/snap/local/bin/generate-presets"
test -f "$REPO_ROOT/snap/local/libexec/generate_presets.py"
