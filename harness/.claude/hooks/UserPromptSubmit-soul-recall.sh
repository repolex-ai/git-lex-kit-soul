#!/bin/bash
set -u

# --- kit-hook opt-out guard (managed; do not edit) ---
_glx_local="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/settings.local.json"
if [ -f "$_glx_local" ] && grep -q disabledHooks "$_glx_local" 2>/dev/null; then
    _glx_self="$(basename "${BASH_SOURCE[0]:-$0}" .sh)"
    if python3 - "$_glx_local" "$_glx_self" <<'PY' 2>/dev/null
import json, sys
cfg, name = sys.argv[1], sys.argv[2]
try:
    with open(cfg) as f:
        disabled = (json.load(f).get("soul") or {}).get("disabledHooks") or []
    sys.exit(0 if name in disabled else 1)
except Exception:
    sys.exit(1)
PY
    then
        exit 0
    fi
fi
# --- end kit-hook opt-out guard ---

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$PROJECT_DIR/.claude/memory-recall.py" ]; then
    exec python3 "$PROJECT_DIR/.claude/memory-recall.py" 2>/dev/null || true
elif [ -f "$HOOK_DIR/UserPromptSubmit-soul-recall.py" ]; then
    exec python3 "$HOOK_DIR/UserPromptSubmit-soul-recall.py" 2>/dev/null || true
fi

exit 0
