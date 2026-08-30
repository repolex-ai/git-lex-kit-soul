#!/bin/bash
# PreCompact-soul-sync.sh (kit-soul) — converge kits AND sync the store at every
# compaction. Replaces PreCompact-soul-kitupdate.sh (Rob, 2026-08-29): same firing
# point, same detached fail-soft shape, one added step.
#
# Naming: <Event>-<kit>-<purpose>.sh (§3.2a). Leading segment `PreCompact` is the CC
# event. SIDE-EFFECT hook (PreCompact supports no context injection — fine, both steps
# are pure shell commands, not model reasoning).
#
# Why PreCompact: compaction is the soul's natural "day boundary" (one journal entry per
# compaction), so it fires at exactly the cadence souls cycle — often enough that
# nothing drifts stale, without being every-turn.
#
# What it does, IN ORDER — the order is load-bearing:
#   1. `git lex kit-update`  — fetch + converge ALL installed kits (hooks, ontology,
#      scaffolds). This is what keeps every soul's hooks identical to canon.
#   2. `git lex sync`        — compile history into the store. Runs AFTER kit-update so
#      it syncs with converged vocabulary (a sync against a stale ontology silently
#      drops new kit vocab until the next sync). In a repo that has run
#      `git lex export-index cottas` once, sync's tail-step also refreshes the COTTAS
#      spine + manifest, so context-caches (squad recall, Gemini) stay fresh for free.
#
# TWO BEHAVIORS WORTH KNOWING (documented, not discovered):
#   - sync WRITES TRACKED FILES (.lex/extract/*.spo sidecars, skip-if-identical). When
#     extraction output changed, the working tree is dirty after compaction — which
#     means SessionEnd-soul-save.sh will commit those sidecars at session end. Derived
#     files that want committing; expected, not a leak.
#   - sync takes the store's exclusive write lock for its whole run, even a no-op. A
#     concurrent writer (a second sync, `git lex verify`, another kit-update) exits
#     with a lock error rather than waiting; it is harmless and the next run succeeds.
#     Kept minimal on purpose — no overlap guard (Rob, 2026-08-29).
#
# DETACHED + fail-soft: network fetch + sync take seconds and must NEVER block or fail
# the compaction. Fire in the background, disown, exit 0 immediately. All output to
# /dev/null (PreCompact stdout is not injected, but keep it clean regardless). If the
# network is down, kit-update bails on its own and sync still runs — harmless, next
# compaction retries.

set -u

# --- kit-hook opt-out guard (managed; do not edit) ---
# A kit-managed hook can't be un-registered locally: CC merges hooks (local ADDS, never
# overrides) and kit-update re-converges settings.json every compaction. This guard is
# the escape hatch — list this hook's basename (no .sh) under soul.disabledHooks in
# .claude/settings.local.json and the hook no-ops. settings.local.json is gitignored and
# never touched by kit-update, so the opt-out is durable + soul-private. Fail-soft: any
# trouble reading/parsing → the hook runs normally (a broken opt-out never silences a hook).
#
# NOTE: disabling THIS hook (PreCompact-soul-sync) stops auto-kit-convergence AND the
# compaction-time sync for this soul — you must re-enable + `git lex kit-update` by hand
# to ever get kit changes (including guard fixes) again. A deliberate, sharp-edged opt-out.
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

# Fire-and-forget: converge kits, then sync, in the background so compaction is never
# blocked. Sequential on purpose — see the order rationale in the header.
(
    cd "$PROJECT_DIR" 2>/dev/null || exit 0
    git lex kit-update >/dev/null 2>&1
    git lex sync       >/dev/null 2>&1
) &
disown 2>/dev/null || true

exit 0
