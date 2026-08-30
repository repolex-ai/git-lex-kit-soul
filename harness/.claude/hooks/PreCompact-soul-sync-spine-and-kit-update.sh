#!/bin/bash
# PreCompact-soul-sync-spine-and-kit-update.sh (kit-soul) — the ONE compaction
# hook (Rob-ruled 2026-08-29, replacing the PreCompact-soul-kitupdate /
# PreCompact-soul-sync pair): converge kits, sync the store, refresh the spine,
# hand off to the cache — sequentially, in one background chain, because Claude
# Code fires same-event hooks in PARALLEL and both steps take the store's
# exclusive write lock (a second writer dies rather than waits). One chain =
# deterministic order, zero self-race, no "maybe it worked".
#
# Why PreCompact, and why the soul kit: compaction is the soul's day boundary —
# if there is no soul, there is nobody to PreCompact for.
#
# The sequence, ORDER LOAD-BEARING:
#   1. `git lex kit-update` — fetch + converge ALL installed kits (hooks,
#      ontology, scaffolds). Runs FIRST so step 2 syncs with converged
#      vocabulary (a sync against a stale ontology silently drops new kit
#      vocab until the next sync).
#   2. `git lex sync` — compile history into the store. Its own tail step
#      writes `.lex/_ignore/spine/<commit>.spine.tsv` (the neural KV-cache
#      index) and spawns `pythia cache update` when pythia is installed —
#      so steps "spine" and "cache" need no lines here; sync carries them.
#
# BEHAVIORS WORTH KNOWING (documented, not discovered):
#   - sync writes tracked files (.lex/extract/*.spo sidecars,
#     skip-if-identical). When extraction output changed, the tree is dirty
#     after compaction and SessionEnd-soul-save.sh commits it. Expected.
#   - sync takes the store's write lock for its whole run, even a no-op. A
#     HUMAN-run writer colliding with this background chain (`git lex verify`
#     right after compaction) exits with a lock error; harmless, retry.
#
# DETACHED + fail-soft: the chain takes seconds and must NEVER block or fail
# the compaction. Fire in the background, disown, exit 0 immediately. All
# output to /dev/null (PreCompact stdout is not injected). Network down →
# kit-update bails on its own, sync still runs; next compaction retries.

set -u

# --- kit-hook opt-out guard (managed; do not edit) ---
# A kit-managed hook can't be un-registered locally: CC merges hooks (local ADDS, never
# overrides) and kit-update re-converges settings.json every compaction. This guard is
# the escape hatch — list this hook's basename (no .sh) under soul.disabledHooks in
# .claude/settings.local.json and the hook no-ops. settings.local.json is gitignored and
# never touched by kit-update, so the opt-out is durable + soul-private. Fail-soft: any
# trouble reading/parsing → the hook runs normally (a broken opt-out never silences a hook).
#
# NOTE: disabling THIS hook stops auto-kit-convergence AND the compaction-time
# sync/spine refresh for this soul — you must re-enable + `git lex kit-update`
# by hand to ever get kit changes (including guard fixes) again. A deliberate,
# sharp-edged opt-out.
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

# Fire-and-forget: one sequential chain in the background so compaction is
# never blocked and the two store-writers can never race each other.
(
    cd "$PROJECT_DIR" 2>/dev/null || exit 0
    git lex kit-update >/dev/null 2>&1
    git lex sync       >/dev/null 2>&1
) &
disown 2>/dev/null || true

exit 0
