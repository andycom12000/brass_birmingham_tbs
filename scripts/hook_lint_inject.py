"""PostToolUse hook: lint edited file + inject for Lua file edits."""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

data = json.load(sys.stdin)
file_path = data.get("tool_input", {}).get("file_path", "").replace("\\", "/")

if not file_path.endswith(".lua"):
    sys.exit(0)

# Get path relative to project root for selene
rel_path = file_path
for prefix in ["C:/Users/andyc/Projects/brass_birmingham_tbs/"]:
    if file_path.startswith(prefix):
        rel_path = file_path[len(prefix):]
        break

messages = []
output = {}

# Skip linting Global.lua (uses TTS #include preprocessor)
basename = os.path.basename(file_path)
is_src = "/src/" in file_path or "/tts/" in file_path

if basename != "Global.lua":
    lint_result = subprocess.run(
        ["selene", rel_path], cwd=ROOT,
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if lint_result.returncode == 0:
        messages.append("Lint: OK")
    else:
        lint_output = (lint_result.stdout or "") + (lint_result.stderr or "")
        # Extract summary
        m = re.search(r"(\d+) errors?\b", lint_output)
        errors = int(m.group(1)) if m else 0
        m = re.search(r"(\d+) warnings?\b", lint_output)
        warnings = int(m.group(1)) if m else 0
        messages.append(f"Lint: {errors} errors, {warnings} warnings")
        # Feed lint output to Claude for auto-fix
        output["additionalContext"] = (
            f"Lint issues found in {rel_path}. Please review and fix:\n\n"
            + lint_output
        )

# Inject only for src/ or tts/ lua files
if is_src:
    inject_result = subprocess.run(
        [sys.executable, "scripts/inject_scripts.py"], cwd=ROOT,
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if inject_result.returncode == 0:
        messages.append("Inject: OK")
    else:
        err = (inject_result.stderr or "").strip().split("\n")[-1] or "unknown error"
        messages.append(f"Inject: FAIL ({err})")

output["systemMessage"] = " | ".join(messages)
print(json.dumps(output))
