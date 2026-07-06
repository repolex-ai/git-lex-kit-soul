#!/bin/bash
# UserPromptSubmit-soul-recall.sh (kit-soul) — memory-recall on every user prompt.
#
# Naming: <Event>-<kit>-<purpose>.sh (§3.2a). The leading segment `UserPromptSubmit`
# is the CC event; git-lex registers this script under it. Multiple kits may ship a
# hook for the same event (this soul-recall + kit-pool's UserPromptSubmit-pool-share.sh)
# — CC runs all registered scripts on the event. This is the un-forked half of the old
# combined UserPromptSubmit.sh; the Pool image-ingest half now lives in kit-pool.
#
# What it does: score the soul's own Soul/Memory + Soul/Note docs against the prompt by
# term-overlap and emit the top matches as additionalContext (JSON to stdout).
#
# STDOUT DISCIPLINE: on UserPromptSubmit, a hook's stdout is injected into the model's
# context. This script's stdout IS that injected context, so memory-recall.py must be
# the ONLY thing here that writes to stdout. (kit-pool's share hook is fire-and-forget
# and writes NOTHING, so the two UserPromptSubmit scripts don't collide on stdout.)
#
# Fail-soft: always exits 0; a recall failure must never block or pollute a prompt.

set -u

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

PAYLOAD="$(cat)"

# CLAUDE_PROJECT_DIR is guarded with ${...:-$PWD}. Under `set -u` a bare
# $CLAUDE_PROJECT_DIR hard-crashes this line in any invocation that doesn't export
# the var (manual run, cron, CI, harness drift), silently zeroing recall — the
# fallback keeps it fail-soft as the header promises. The 2>/dev/null guard swallows
# any python errors so they never leak into the injected context.
printf '%s' "$PAYLOAD" | python3 "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/memory-recall.py" 2>/dev/null

exit 0
