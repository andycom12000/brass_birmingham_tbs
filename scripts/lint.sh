#!/usr/bin/env bash
# Lint all Lua files with selene.
# Skips tts/Global.lua because it uses TTS #include preprocessor directives.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

# Collect all tts/*.lua except Global.lua
TTS_FILES=()
for f in tts/*.lua; do
    [[ "$(basename "$f")" == "Global.lua" ]] && continue
    TTS_FILES+=("$f")
done

selene src/ "${TTS_FILES[@]}" "$@"
