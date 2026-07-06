#!/bin/bash
# PreCompact-soul-kitupdate.sh (kit-soul) — auto-converge kits at every compaction.
#
# Naming: <Event>-<kit>-<purpose>.sh (§3.2a). Leading segment `PreCompact` is the CC
# event. This is a SIDE-EFFECT hook (PreCompact supports no context injection — that's
# fine, kit-update is a pure shell command, not model reasoning).
#
# Why PreCompact: compaction is the soul's natural "day boundary" (one journal entry per
# compaction), so it fires at exactly the cadence souls cycle — often enough that no soul
# ever drifts onto stale hooks, without being every-turn. Kits change infrequently, so
# most fires are a quick fetch → see-no-change → exit; the rare real update is worth the
# download.
#
# What it does: `git lex kit-update` (no args = ALL installed kits: soul + pool + copia +
# whatever) — fetches each fresh and CONVERGES it. Hook scripts auto-overwrite to the kit
# version (is_enforced_path), so this is what keeps every soul's hooks identical to canon.
# The prior local is stashed to .kit-pre-force/ and the vendored .lex/kit/ copy is tracked
# in git, so a bad/interrupted fetch is always recoverable (git checkout .lex/kit/).
#
# DETACHED + fail-soft: kit-update does a network fetch (seconds) and must NEVER block or
# fail the compaction. We fire it in the background, disown, and exit 0 immediately. All
# output to /dev/null (PreCompact stdout is not injected, but keep it clean regardless).
# If the network is down, kit-update bails on its own — harmless, next compaction retries.

set -u

# --- kit-hook opt-out guard (managed; do not edit) ---
# A kit-managed hook can't be un-registered locally: CC merges hooks (local ADDS, never
# overrides) and kit-update re-converges settings.json every compaction. This guard is
# the escape hatch — list this hook's basename (no .sh) under soul.disabledHooks in
# .claude/settings.local.json and the hook no-ops. settings.local.json is gitignored and
# never touched by kit-update, so the opt-out is durable + soul-private. Fail-soft: any
# trouble reading/parsing → the hook runs normally (a broken opt-out never silences a hook).
#
# NOTE: disabling THIS hook (PreCompact-soul-kitupdate) stops auto-kit-convergence for
# this soul — the one hook you must re-enable + `git lex kit-update` by hand to ever get
# kit changes (including guard fixes) again. A deliberate, sharp-edged opt-out.
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

# Fire-and-forget: converge all kits in the background so compaction is never blocked.
(
    cd "$PROJECT_DIR" 2>/dev/null || exit 0
    git lex kit-update >/dev/null 2>&1
) &
disown 2>/dev/null || true

exit 0
