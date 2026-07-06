#!/bin/bash
# SessionEnd hook — runs once when a Claude Code session terminates.
#
# Purpose: catch the last few minutes of the live JSONL into the Raw/ mirror
# before the session goes static. The git-lex raw-mirror adapter already
# catches it byte-faithfully on the *next* `git lex save`, but that may be
# in a future session. This hook closes the window so end-of-session bytes
# are committed in the same git commit, attributed to this session.
#
# Strategy:
#   1. Parse stdin JSON for the exit reason via matcher_value.
#   2. If the repo has anything to save, run `git lex save` once.
#      The raw-mirror adapter inside save will pick up the latest JSONL bytes.
#   3. Stay silent on success; surface to stderr only on real failure.
#
# Timeout: this hook gets ~5s. `git lex save` may exceed that on big diffs;
# we accept the timeout as a soft cap — partial progress is fine, the source
# JSONL is still durable on disk and the next save will catch up anyway.

set -e

# --- kit-hook opt-out guard (managed; do not edit) ---
# A kit-managed hook can't be un-registered locally: CC merges hooks (local ADDS, never
# overrides) and kit-update re-converges settings.json every compaction. This guard is
# the escape hatch — list this hook's basename (no .sh) under soul.disabledHooks in
# .claude/settings.local.json and the hook no-ops. settings.local.json is gitignored and
# never touched by kit-update, so the opt-out is durable + soul-private. Fail-soft: any
# trouble reading/parsing → the hook runs normally (a broken opt-out never silences a hook).
# (Safe under `set -e`: a non-zero exit inside an `if` condition never triggers -e.)
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

HOOK_INPUT="$(cat 2>/dev/null || true)"

# Extract matcher_value (exit reason) — useful for skipping non-real-end events
# like /clear that might still fire SessionEnd in some Claude versions.
MATCHER="$(printf '%s' "$HOOK_INPUT" | python3 -c 'import sys,json
try:
    print(json.loads(sys.stdin.read() or "{}").get("matcher_value",""))
except Exception:
    pass' 2>/dev/null)"

# Only catch real session-ends, not /clear or /resume. (/compact is its own
# wake-source — handled separately, but it does end this session so we want
# the catch here too.)
case "$MATCHER" in
    clear|resume)
        exit 0
        ;;
esac

# Run git lex save if the working tree has anything to save.
# The raw-mirror adapter inside save handles the JSONL mirror automatically.
cd "$CLAUDE_PROJECT_DIR" || exit 0

if [ -n "$(git status --porcelain 2>/dev/null)" ] || \
   [ -n "$(find "$HOME/.claude/projects" -name '*.jsonl' -newer "$CLAUDE_PROJECT_DIR/.git/HEAD" 2>/dev/null | head -1)" ]; then
    git lex save "SessionEnd auto-save — catch latest JSONL bytes before session goes static. (reason: $MATCHER)" \
        >/dev/null 2>&1 || true
fi

exit 0
