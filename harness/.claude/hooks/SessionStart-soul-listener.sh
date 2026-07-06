#!/bin/bash
# SessionStart hook — runs once per Claude Code session.
#
# Does three things:
#   1. Parse stdin JSON for the wake source (startup / resume / clear /
#      compact) into $WAKE_SOURCE so later blocks can gate on it.
#   2. Start the git-lex notify server (if not already up).
#   3. Start the soul listener for peer messages.
#
# Identity note: git identity (GIT_AUTHOR_*/GIT_COMMITTER_*) is injected
# by Claude Code from .claude/settings.json's `env:` block, not from .env.

# --- kit-hook opt-out guard (managed; do not edit) ---
# A kit-managed hook can't be un-registered locally: CC merges hooks (local ADDS, never
# overrides) and kit-update re-converges settings.json every compaction. This guard is
# the escape hatch — list this hook's basename (no .sh) under soul.disabledHooks in
# .claude/settings.local.json and the hook no-ops. settings.local.json is gitignored and
# never touched by kit-update, so the opt-out is durable + soul-private. Fail-soft: any
# trouble reading/parsing → the hook runs normally (a broken opt-out never silences a hook).
_glx_local="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/settings.local.json"
# Fast path: no file, or the key is absent → not disabled, skip the python spawn entirely
# (the common case pays nothing). Only parse when a disabledHooks list actually exists.
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
    sys.exit(1)   # no file / bad json / no key → NOT disabled, run the hook
PY
    then
        exit 0
    fi
fi
# --- end kit-hook opt-out guard ---

# 1. Read Claude Code's JSON input and extract the wake source.
HOOK_INPUT="$(cat 2>/dev/null || true)"
WAKE_SOURCE="$(printf '%s' "$HOOK_INPUT" | python3 -c 'import sys,json
try:
    print(json.loads(sys.stdin.read() or "{}").get("source",""))
except Exception:
    pass' 2>/dev/null)"

# 2. Start the git-lex listen server if not already running.
if ! lsof -i:7879 >/dev/null 2>&1; then
    git lex serve listen --port 7879 >/dev/null 2>&1 &
    sleep 1
fi

# 3. Start the soul listener in the background.
# Tied to the parent process group so it dies with this session.
if [ -f "$CLAUDE_PROJECT_DIR/.claude/soul-listener.py" ]; then
    python3 "$CLAUDE_PROJECT_DIR/.claude/soul-listener.py" &
fi

# 4. Wake-source-gated hooks — extend locally to run work only on real wakes
# (startup / compact) versus mid-session events (resume / clear).
# Example: deliver a pre-staged dream or surface a status indicator.
case "$WAKE_SOURCE" in
    startup|compact)
        : # add startup/compact-only work here in your local fork
        ;;
esac

exit 0
