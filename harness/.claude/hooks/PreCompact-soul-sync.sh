#!/bin/bash
# PreCompact-soul-sync.sh (kit-soul) — sync the store at every compaction.
#
# Naming: <Event>-<kit>-<purpose>.sh (§3.2a). Leading segment `PreCompact` is the CC
# event. SIDE-EFFECT hook (PreCompact supports no context injection — fine, sync is a
# pure shell command, not model reasoning).
#
# Why PreCompact: compaction is the soul's natural "day boundary" (one journal entry
# per compaction). Syncing here means the store — and, in a repo that has run
# `git lex export-index cottas` once, the COTTAS spine + manifest that sync's
# tail-step refreshes — is fresh at exactly the cadence souls cycle, so context
# caches (squad recall, Gemini) never serve a stale soul.
#
# RUNS IN PARALLEL with PreCompact-soul-kitupdate.sh — Claude Code fires all hooks
# for an event at once, and both hooks detach their work besides (Rob, 2026-08-29:
# two separate hooks, minimal, no coordination). Two consequences, accepted:
#   - No ordering: on the rare compaction where kit-update actually lands new
#     vocabulary, this sync may run against the pre-update ontology; the next
#     compaction's sync heals it.
#   - Lock races are possible: sync takes the store's exclusive write lock for its
#     whole run (even a no-op), kit-update takes it briefly at its tail, and a loser
#     exits with a lock error rather than waiting. Harmless — background, silent,
#     retried next compaction. In practice the fetch delay in kit-update usually
#     keeps the two windows apart.
#
# ONE MORE DOCUMENTED BEHAVIOR: sync writes tracked files (.lex/extract/*.spo
# sidecars, skip-if-identical). When extraction output changed, the working tree is
# dirty after compaction — so SessionEnd-soul-save.sh will commit those sidecars at
# session end. Derived files that want committing; expected, not a leak.
#
# DETACHED + fail-soft: sync takes seconds and must NEVER block or fail the
# compaction. Fire in the background, disown, exit 0 immediately. All output to
# /dev/null (PreCompact stdout is not injected, but keep it clean regardless).

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

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Fire-and-forget: sync in the background so compaction is never blocked.
(
    cd "$PROJECT_DIR" 2>/dev/null || exit 0
    git lex sync >/dev/null 2>&1
) &
disown 2>/dev/null || true

exit 0
